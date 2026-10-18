"""Hash Git's staged bytes, including normalized text, for the v1.3 client repo."""
import argparse,hashlib,pathlib,subprocess

def update(repository):
    repository=pathlib.Path(repository).resolve()
    remote=subprocess.check_output(['git','-C',str(repository),'remote','get-url','origin'],text=True).strip()
    assert remote=='https://github.com/RebarFw/Tanki-Era-.git','Unexpected publication repository'
    entries=subprocess.check_output(['git','-C',str(repository),'ls-files','-s','-z']).split(b'\0');rows=[];digests={}
    for item in entries:
        if not item:continue
        meta,name=item.split(b'\t',1);name=name.decode();mode,oid,stage=meta.decode().split()
        assert stage=='0'
        if name=='SHA256SUMS.txt':continue
        if oid not in digests:digests[oid]=hashlib.sha256(subprocess.check_output(['git','-C',str(repository),'cat-file','blob',oid])).hexdigest()
        rows.append((name,digests[oid]))
    (repository/'SHA256SUMS.txt').write_text(''.join(d+'  '+name+'\n'for name,d in sorted(rows)),encoding='utf-8',newline='\n')
    subprocess.run(['git','-C',str(repository),'add','--','SHA256SUMS.txt'],check=True)
    return len(rows)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--repository',required=True);args=parser.parse_args()
    print('CLIENT_REPOSITORY_CHECKSUMS_UPDATED',update(args.repository))
