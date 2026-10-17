"""Add existing ERA PNG artwork as ordinary Windows RT_ICON resources.

The native entry code and original Windows manifest are unchanged. This is a
requested branding change; scan and test its exact output before publishing.
"""
from pathlib import Path
import ctypes,struct,hashlib,pefile
from PIL import Image

def brand(executable:Path,art:Path):
 before=pefile.PE(str(executable));code={s.Name.decode().strip('\0'):s.get_data()for s in before.sections if s.Name.strip(b'\0')!=b'.rsrc'}
 entry=next(e for e in before.DIRECTORY_ENTRY_RESOURCE.entries if e.id==24).directory.entries[0].directory.entries[0].data.struct
 manifest=before.get_data(entry.OffsetToData,entry.Size);before.close();frames=[]
 for size in [16,32,48,128]:
  raw=(art/f'icon{size}.png').read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'and struct.unpack('>II',raw[16:24])==(size,size)
  # Windows' standard 32-bit DIB icon format, including the transparency mask.
  # Preserve the exact existing artwork pixels; do not redraw or obscure assets.
  pixels=Image.open(art/f'icon{size}.png').convert('RGBA')
  xor=b''.join(pixels.crop((0,y,size,y+1)).tobytes('raw','BGRA')for y in range(size-1,-1,-1))
  stride=((size+31)//32)*4;mask=bytearray(stride*size)
  for y in range(size):
   for x in range(size):
    if pixels.getpixel((x,size-1-y))[3]==0:mask[y*stride+x//8]|=128>>(x%8)
  dib=struct.pack('<IiiHHIIiiII',40,size,size*2,1,32,0,len(xor)+len(mask),0,0,0,0)+xor+mask
  frames.append((size,dib))
 group=struct.pack('<HHH',0,1,len(frames))+b''.join(struct.pack('<BBBBHHIH',size,size,0,0,1,32,len(raw),i)for i,(size,raw)in enumerate(frames,101))
 kernel=ctypes.WinDLL('kernel32',use_last_error=True)
 kernel.BeginUpdateResourceW.argtypes=[ctypes.c_wchar_p,ctypes.c_int];kernel.BeginUpdateResourceW.restype=ctypes.c_void_p
 kernel.UpdateResourceW.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_ushort,ctypes.c_void_p,ctypes.c_uint];kernel.UpdateResourceW.restype=ctypes.c_int
 kernel.EndUpdateResourceW.argtypes=[ctypes.c_void_p,ctypes.c_int];kernel.EndUpdateResourceW.restype=ctypes.c_int
 handle=kernel.BeginUpdateResourceW(str(executable.resolve()),False)
 if not handle:raise ctypes.WinError(ctypes.get_last_error())
 try:
  for ident,(_,raw)in enumerate(frames,101):
   buf=ctypes.create_string_buffer(raw)
   if not kernel.UpdateResourceW(handle,ctypes.c_void_p(3),ctypes.c_void_p(ident),1033,buf,len(raw)):raise ctypes.WinError(ctypes.get_last_error())
  buf=ctypes.create_string_buffer(group)
  if not kernel.UpdateResourceW(handle,ctypes.c_void_p(14),ctypes.c_void_p(100),1033,buf,len(group)):raise ctypes.WinError(ctypes.get_last_error())
 except Exception:
  kernel.EndUpdateResourceW(handle,True);raise
 if not kernel.EndUpdateResourceW(handle,False):raise ctypes.WinError(ctypes.get_last_error())
 after=pefile.PE(str(executable));assert code=={s.Name.decode().strip('\0'):s.get_data()for s in after.sections if s.Name.strip(b'\0')!=b'.rsrc'}
 resources={e.id:e for e in after.DIRECTORY_ENTRY_RESOURCE.entries};assert set(resources)=={3,14,24}
 for ident,(_,raw)in enumerate(frames,101):
  d=next(e for e in resources[3].directory.entries if e.id==ident).directory.entries[0].data.struct
  assert after.get_data(d.OffsetToData,d.Size)==raw
 d=resources[24].directory.entries[0].directory.entries[0].data.struct;assert after.get_data(d.OffsetToData,d.Size)==manifest
 result={'passed':True,'icon_frames':[s for s,_ in frames],'standard_windows_dib_icons':True,'original_artwork_pixels_preserved':True,'non_resource_sections_identical':True,'original_manifest_identical':True,'only_resource_types_added':[3,14],'exe_sha256':hashlib.sha256(executable.read_bytes()).hexdigest()};after.close();return result
