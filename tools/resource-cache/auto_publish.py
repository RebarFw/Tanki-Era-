"""Debounced, single-instance resource publication; never edits accounts or game JARs."""
from __future__ import annotations
import argparse,hashlib,json,os,pathlib,subprocess,sys,time,traceback
from refresh import refresh,activate,atomic

def signature(data):
    h=hashlib.sha256()
    for path in [data/'assets/resource-cache/v1/manifest.json',*sorted((data/'static/original').rglob('*'))]:
        if not path.is_file():continue
        stat=path.stat();h.update((str(path.relative_to(data))+':'+str(stat.st_mtime_ns)+':'+str(stat.st_size)).encode())
    return h.hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime',type=pathlib.Path,required=True)
    parser.add_argument('--once',action='store_true');args=parser.parse_args();runtime=args.runtime.resolve()
    home=runtime/'resource-publication';home.mkdir(exist_ok=True)
    lock=home/'publisher.lock'
    if os.name=='nt':
        import msvcrt
        handle=lock.open('a+b');handle.seek(0);handle.write(b'0');handle.flush();handle.seek(0)
        deadline=time.monotonic()+1800
        while True:
            try:msvcrt.locking(handle.fileno(),msvcrt.LK_NBLCK,1);break
            except OSError:
                if not args.once:print('Resource publisher already running',flush=True);return
                if time.monotonic()>=deadline:raise RuntimeError('Timed out waiting for resource publication')
                time.sleep(1)
    else:
        import fcntl
        handle=lock.open('a+b');fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
    atomic(home/'publisher.pid',(str(os.getpid())+'\n').encode())
    data=runtime/'src/main/resources/data';source=data/'assets/resource-cache/v1';target=runtime/'build/data/assets/resource-cache/v1'
    state_path=home/'state.json';state=json.loads(state_path.read_text())if state_path.exists()else{}
    stable=None;observed_at=time.monotonic();retry_at=0.
    while True:
        enabled=home/'enabled.json'
        if not enabled.exists()or not json.loads(enabled.read_text()).get('enabled'):
            if args.once:raise RuntimeError('Resource publication has not been enabled after validation')
            time.sleep(10);continue
        current=signature(data)
        if args.once and current==state.get('signature'):
            print('Resource cache is already published and active',flush=True);return
        if current!=stable:stable=current;observed_at=time.monotonic()
        ready=args.once or (current!=state.get('signature')and time.monotonic()-observed_at>=20)
        if ready and time.monotonic()>=retry_at:
            try:
                # Global decoder version changes are deployment operations,
                # not safe background byte updates for existing memberships.
                active=(source/'active-release.sha256').read_text().strip()
                published=json.loads((source/('manifest-'+active+'.json')).read_bytes())
                authoring=json.loads((source/'manifest.json').read_bytes())
                if published['cacheVersionBump']!=authoring['cacheVersionBump']:raise RuntimeError('Cache version bump needs an explicit coordinated deployment')
                changed=refresh(source,data/'static/original')
                job=home/'pending';job.mkdir(exist_ok=True)
                subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('publish.py')),'--cache-root',str(source),'--output',str(job),'--publish'],check=True)
                subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('verify_public.py')),'--publication',str(job/'publication.json'),'--only-new'],check=True)
                digest=activate(source,target,job)
                stable=signature(data);state=dict(signature=stable,manifest_sha256=digest,changed_packages=changed,published_at=time.time(),error=None)
                atomic(state_path,json.dumps(state,indent=2).encode());print('RESOURCE_CACHE_AUTO_PUBLISHED '+digest,flush=True)
            except Exception as error:
                state['error']=str(error);atomic(state_path,json.dumps(state,indent=2).encode());traceback.print_exc();retry_at=time.monotonic()+300
                if args.once:raise
        if args.once:return
        time.sleep(10)

if __name__=='__main__':main()
