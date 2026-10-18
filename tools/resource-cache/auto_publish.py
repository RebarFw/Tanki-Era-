"""Debounced, single-instance resource publication; never edits accounts or game JARs."""
from __future__ import annotations
import argparse,contextlib,hashlib,json,os,pathlib,subprocess,sys,time,traceback
from refresh import refresh,activate,atomic

def signature(data):
    h=hashlib.sha256()
    for path in [data/'assets/resource-cache/v1/manifest.json',*sorted((data/'static/original').rglob('*'))]:
        if not path.is_file():continue
        try:stat=path.stat()
        except FileNotFoundError:continue
        h.update((str(path.relative_to(data))+':'+str(stat.st_mtime_ns)+':'+str(stat.st_size)).encode())
    return h.hexdigest()

@contextlib.contextmanager
def exclusive(path,wait=False):
    handle=path.open('a+b');handle.seek(0);handle.write(b'0');handle.flush();handle.seek(0)
    locked=False;deadline=time.monotonic()+1800
    try:
        while True:
            try:
                if os.name=='nt':
                    import msvcrt
                    msvcrt.locking(handle.fileno(),msvcrt.LK_NBLCK,1)
                else:
                    import fcntl
                    fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
                locked=True;break
            except OSError:
                if not wait:break
                if time.monotonic()>=deadline:raise RuntimeError('Timed out waiting for resource publication')
                time.sleep(.25)
        yield locked
    finally:
        if locked:
            handle.seek(0)
            if os.name=='nt':msvcrt.locking(handle.fileno(),msvcrt.LK_UNLCK,1)
            else:fcntl.flock(handle,fcntl.LOCK_UN)
        handle.close()

def enabled(home):
    path=home/'enabled.json'
    try:return path.exists()and json.loads(path.read_text()).get('enabled')is True
    except (ValueError,OSError):return False

def state(home):
    path=home/'state.json'
    return json.loads(path.read_text())if path.exists()else{}

def publish_once(runtime,home,wait):
    # The long-lived watcher owns watcher.lock; only actual publications own
    # publication.lock. An explicit game update can therefore run while idle.
    with exclusive(home/'publication.lock',wait)as locked:
        if not locked:return False
        if not enabled(home):raise RuntimeError('Resource publication is disabled')
        data=runtime/'src/main/resources/data';source=data/'assets/resource-cache/v1';target=runtime/'build/data/assets/resource-cache/v1'
        current=signature(data);previous=state(home)
        if current==previous.get('signature'):
            print('Resource cache is already published and active',flush=True);return True
        active=(source/'active-release.sha256').read_text().strip()
        published=json.loads((source/('manifest-'+active+'.json')).read_bytes());authoring=json.loads((source/'manifest.json').read_bytes())
        if published['cacheVersionBump']!=authoring['cacheVersionBump']:raise RuntimeError('Cache version bump needs an explicit coordinated deployment')
        changed=refresh(source,data/'static/original');job=home/'pending';job.mkdir(exist_ok=True)
        subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('publish.py')),'--cache-root',str(source),'--output',str(job),'--publish'],check=True)
        subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('verify_public.py')),'--publication',str(job/'publication.json'),'--only-new'],check=True)
        if not enabled(home):raise RuntimeError('Publisher disabled during transfer; active generation retained')
        digest=activate(source,target,job)
        result=dict(signature=signature(data),manifest_sha256=digest,changed_packages=changed,published_at=time.time(),error=None)
        atomic(home/'state.json',json.dumps(result,indent=2).encode());print('RESOURCE_CACHE_AUTO_PUBLISHED '+digest,flush=True)
        return True

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime',type=pathlib.Path,required=True);parser.add_argument('--once',action='store_true')
    args=parser.parse_args();runtime=args.runtime.resolve();home=runtime/'resource-publication';home.mkdir(exist_ok=True)
    if args.once:publish_once(runtime,home,True);return
    with exclusive(home/'watcher.lock')as locked:
        if not locked:print('Resource watcher already running',flush=True);return
        atomic(home/'publisher.pid',(str(os.getpid())+'\n').encode())
        data=runtime/'src/main/resources/data';stable=None;observed_at=time.monotonic();retry_at=0.
        while True:
            if not enabled(home):time.sleep(10);continue
            current=signature(data)
            if current!=stable:stable=current;observed_at=time.monotonic()
            if current!=state(home).get('signature')and time.monotonic()-observed_at>=20 and time.monotonic()>=retry_at:
                try:publish_once(runtime,home,False)
                except Exception as error:
                    result=state(home);result['error']=str(error);atomic(home/'state.json',json.dumps(result,indent=2).encode());traceback.print_exc();retry_at=time.monotonic()+300
            time.sleep(10)

if __name__=='__main__':main()
