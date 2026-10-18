import copy,hashlib,json,pathlib,struct,tempfile,unittest
from publish import canonical,validate_cache
from refresh import refresh,activate,snapshot,atomic

def bundle(root,name,resources):
    rows=[];payload=bytearray()
    for key,files in resources.items():
        for filename,data in files.items():
            rows.append(dict(path=key.replace(':','/')+'/'+filename,sha256=hashlib.sha256(data).hexdigest(),size=len(data),offset=len(payload)));payload.extend(data)
    header=canonical(dict(format=1,files=rows));binary=b'TEPK\x01'+struct.pack('>I',len(header))+header+payload
    digest=hashlib.sha256(binary).hexdigest();path='packages/'+digest+'.tpk';atomic(root/path,binary)
    return dict(group='core',path=path,resources=list(resources),sha256=digest,size=len(binary),version=digest)

class Pipeline(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.home=pathlib.Path(self.temp.name);self.cache=self.home/'cache';self.static=self.home/'static';self.cache.mkdir()
        self.parts={'one':{'1:1':{'image.png':b'first'}},'two':{'2:1':{'image.png':b'second'}}}
        resources={};packages={}
        for name,content in self.parts.items():
            packages[name]=bundle(self.cache,name,content)
            for key,files in content.items():
                metadata={}
                for filename,data in files.items():
                    path=key.replace(':','/')+'/'+filename;atomic(self.static/path,data)
                    metadata[filename]=dict(path=path,sha256=hashlib.sha256(data).hexdigest(),size=len(data))
                resource_id,version=map(int,key.split(':'));resources[key]=dict(id=resource_id,version=version,package=name,files=metadata,scope='common',type=10,revision='original')
        self.manifest=dict(format=1,cacheVersionBump=854977,common=list(resources),maps={'map':dict(resources=list(resources))},resources=resources,packages=packages,version='initial')
        self.write(self.manifest);old=(self.cache/'manifest.json').read_bytes();self.old_sha=snapshot(self.cache,old);atomic(self.cache/'active-release.sha256',(self.old_sha+'\n').encode())
    def tearDown(self):self.temp.cleanup()
    def write(self,m):
        data=canonical(m);atomic(self.cache/'manifest.json',data);atomic(self.cache/'manifest.sha256',(hashlib.sha256(data).hexdigest()+'\n').encode())
    def test_complete_coverage(self):self.assertTrue(validate_cache(self.cache)[1]['all_required_resources_covered'])
    def test_unchanged_cache_reuses_every_bundle(self):
        before=copy.deepcopy(self.manifest['packages']);self.assertEqual(refresh(self.cache,self.static),[]);self.assertEqual(json.loads((self.cache/'manifest.json').read_bytes())['packages'],before)
    def test_one_edit_rebuilds_only_its_bucket(self):
        atomic(self.static/'1/1/image.png',b'changed')
        self.assertEqual(refresh(self.cache,self.static),['one']);m=json.loads((self.cache/'manifest.json').read_bytes())
        self.assertEqual(m['packages']['two'],self.manifest['packages']['two']);self.assertNotEqual(m['packages']['one']['sha256'],self.manifest['packages']['one']['sha256'])
        self.assertEqual(m['cacheVersionBump'],854977);validate_cache(self.cache)
    def test_new_texture_in_registered_resource_is_included(self):
        atomic(self.static/'1/1/extra.jpg',b'additional texture')
        self.assertEqual(refresh(self.cache,self.static),['one']);m=json.loads((self.cache/'manifest.json').read_bytes());self.assertIn('extra.jpg',m['resources']['1:1']['files']);validate_cache(self.cache)
    def test_unregistered_asset_is_not_invented_as_a_common_resource(self):
        atomic(self.static/'999/1/image.jpg',b'not registered');self.assertEqual(refresh(self.cache,self.static),[])
        self.assertNotIn('999:1',json.loads((self.cache/'manifest.json').read_bytes())['resources'])
    def test_corrupted_bundle_rejected(self):
        p=self.cache/self.manifest['packages']['one']['path'];p.write_bytes(b'corrupt')
        with self.assertRaises(AssertionError):validate_cache(self.cache)
    def test_missing_required_resource_rejected(self):
        m=copy.deepcopy(self.manifest);m['common'].append('999:1');self.write(m)
        with self.assertRaises(AssertionError):validate_cache(self.cache)
    def test_authoring_edit_cannot_change_active_generation(self):
        m=copy.deepcopy(self.manifest);m['version']='not yet uploaded';self.write(m)
        self.assertEqual((self.cache/'active-release.sha256').read_text().strip(),self.old_sha)
        self.assertEqual(json.loads((self.cache/('manifest-'+self.old_sha+'.json')).read_bytes())['version'],'initial')
    def test_activation_installs_content_before_pointer_and_preserves_rollback(self):
        candidate=self.home/'candidate';candidate.mkdir();m=copy.deepcopy(self.manifest);m['version']='published';data=canonical(m)
        atomic(candidate/'manifest.json',data);atomic(candidate/'manifest.sha256',(hashlib.sha256(data).hexdigest()+'\n').encode())
        runtime=self.home/'runtime';new_sha=activate(self.cache,runtime,candidate)
        for root in [self.cache,runtime]:
            self.assertEqual((root/'active-release.sha256').read_text().strip(),new_sha)
            self.assertEqual((root/('manifest-'+new_sha+'.json')).read_bytes(),data);validate_cache(root)
        self.assertTrue((self.cache/('manifest-'+self.old_sha+'.json')).is_file())
    def test_immutable_snapshot_cannot_be_overwritten(self):
        path=self.cache/('manifest-'+self.old_sha+'.json');path.write_bytes(b'bad')
        with self.assertRaises(AssertionError):snapshot(self.cache,canonical(self.manifest))

if __name__=='__main__':unittest.main()
