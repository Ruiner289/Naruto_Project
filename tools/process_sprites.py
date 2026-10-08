"""Reproducible manual-cell sprite extraction. Never modifies source files."""
from pathlib import Path
from collections import deque
import json, hashlib
from statistics import median
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
STATES=['idle','move','attack','hit','ko']
# index, row rectangles from visual review, individual cell boundaries
CONFIG={
20:('naruto',[(10,58,[0,45,89,133,176]),(148,49,[0,70,140,210,280,350,420]),(705,56,[0,62,123,184,244]),(1029,58,[0,54,106]),(1097,44,[0,60,120,180,240])],(48,200,152)),
22:('sasuke',[(10,59,[0,45,89,133,176]),(142,53,[0,60,119,178,237,296,354]),(708,56,[0,63,125,187,248]),(1025,51,[0,48,94]),(1086,32,[0,60,120,180,240])],(0,120,0)),
45:('sakura',[(10,61,[0,39,78,115,152]),(151,49,[0,55,110,166,220,276,330]),(694,49,[0,61,122,183]),(1000,50,[0,40,78]),(1060,39,[0,61,121,181,240])],(0,136,0)),
46:('kakashi',[(10,61,[0,61,121,181,240]),(169,68,[0,78,155,232,309,386,462]),(863,69,[0,69,137,205,272]),(1262,61,[0,62,112]),(1333,51,[0,84,168,252,336])],(0,144,0)),
49:('generic_big_sound',[(0,65,[0,66,132,196]),(132,65,[0,68,136,204,272,336]),(65,66,[0,121,242,363,484,605]),(198,72,[0,74,146]),(339,65,[0,74,148,222,296,370,442])],(48,200,152)),
51:('generic_dart',[(0,58,[0,50,100,150,198]),(58,56,[0,74,148,222,296,370,444,518,592]),(114,58,[0,58,113]),(172,50,[0,48]),(222,48,[0,66,132,198,264,322])],(48,120,88)),
52:('generic_claw',[(0,65,[0,53,106,155]),(0,65,[0,53,106,155]),(65,73,[0,74,148,222,296,346]),(268,56,[0,45,88]),(383,38,[0,68,134])],(48,200,152)),
53:('generic_pole',[(0,81,[0,82,164,246,327]),(0,81,[0,82,164,246,327]),(81,67,[0,114,228,342,451]),(373,63,[0,51]),(436,67,[0,90,180,270,360,450,540,630])],(72,120,128)),
62:('generic_flail',[(0,72,[0,42,84,126,168,210,252]),(72,69,[0,74,148,222,296,370,444,518,592,666,740,814,888,962]),(409,88,[0,108,216,324,432,540,648,756,864,970]),(757,67,[0,50,98]),(881,39,[0,74,148,222,296,370,444,518,592,666,738])],(0,112,248)),
63:('generic_scythe',[(0,50,[0,44,88,132,174]),(159,57,[0,58,114]),(50,51,[0,58,116,174,232,288]),(218,56,[0,43,84]),(317,57,[0,61,122,183,244,305])],(48,200,152))}

# Second batch: visually verified DS Idle/Running/Combo 1/Hurt/Knocked Back rows.
CONFIG.update({
4:('shikamaru',[(12,65,[0,38,74,110,146,180]),(171,57,[0,54,106,158,210,262,312]),(851,65,[0,62,122,182,242,300]),(1241,65,[0,54,104]),(1320,41,[0,78,154,230,306,382,458,532])],(232,232,0)),
16:('shino',[(12,64,[0,38,74,110,146,182,218,252]),(171,55,[0,64,126,188,250,312,372]),(829,65,[0,62,122,182,240]),(1293,66,[0,54,106,158,208]),(1373,44,[0,70,138,206,272])],(0,128,0)),
17:('choji',[(12,58,[0,38,74,110,146,182,218,254,290,326,362,398,432]),(157,64,[0,54,106,158,210,262,312]),(797,57,[0,54,106,158,208]),(1164,58,[0,54,104]),(1236,52,[0,70,138,206,274,340])],(48,200,152)),
18:('ino',[(12,57,[0,38,74,110,146,182,216]),(155,58,[0,70,138,206,274,342,408]),(793,57,[0,70,138,206,272]),(1143,57,[0,46,88]),(1214,48,[0,62,122,182,242,302,362,422,482,540])],(56,192,48)),
25:('kiba',[(12,53,[0,46,90,134,178,222,264]),(149,53,[0,62,122,182,242,302,360]),(765,53,[0,62,122,182,240]),(1279,54,[0,54,104]),(1347,33,[0,70,138,206,274,342,410,478,544])],(48,152,152)),
48:('hinata',[(12,55,[0,46,90,134,176]),(152,57,[0,54,106,158,210,262,312]),(784,53,[0,62,122,182,242,300]),(1126,56,[0,54,104]),(1196,39,[0,62,122,182,240])],(32,136,8))})
# Third batch: Asuma basic blade combo; user-selected alternate Kurenai sheet.
CONFIG.update({
64:('asuma',[(315,75,[0,56,102,149,196]),(440,70,[250,320,375,431,495,555]),(684,76,[0,78,158,246,321,401,482,564,642,718]),(568,72,[0,58,137]),(568,72,[58,138,221,305])],(0,128,0)),
66:('kurenai',[(65,80,[0,48,84,120,159]),(205,75,[0,61,106,169,223,294]),(875,75,[0,48,101,153]),(490,70,[0,57,131]),(490,70,[58,131,196])],(0,128,0))})
# Guy team: neutral stance, running, ordinary combo, hurt and knocked-back rows.
CONFIG.update({
7:('lee',[(1238,56,[0,44,88,132,174]),(357,49,[0,54,108,162,216,270,322]),(0,56,[0,50,100,150,198]),(832,58,[0,55,108]),(892,46,[0,66,132,198,264,328])],(48,200,152)),
8:('guy',[(1464,72,[0,42,84,126,166]),(452,68,[0,78,156,234,312,390,466]),(0,72,[0,66,132,198,264,328]),(1062,96,[0,50,98]),(1160,32,[0,74,148,222,294])],(144,152,184)),
43:('tenten',[(1321,56,[0,42,84,126,166]),(373,48,[0,58,116,174,232,290,346]),(0,56,[0,58,116,174,230]),(855,91,[0,59,116]),(1041,38,[0,59,118,177,234])],(168,168,152)),
47:('neji',[(1259,58,[0,46,92,138,182]),(391,50,[0,59,118,177,236,295,352]),(0,52,[0,63,126,189,252,313]),(906,64,[0,49,96]),(972,45,[0,66,132,198,264,328])],(48,152,152))})
RANGED_ROWS={43:(805,48,[0,58,116,172]),22:(585,53,[0,61,121,180]),4:(706,57,[0,62,122,182,240]),16:(682,65,[0,59,116,171]),48:(646,53,[0,62,122,182,242,300])}
IMPACT_FRAMES={7:1,8:2,43:1,47:2,20:2,22:2,45:1,46:2,49:3,51:1,52:3,53:2,62:7,63:3,4:2,16:2,17:2,18:1,25:2,48:2,64:5,66:1}

def flood_remove(im, colors):
 im=im.convert('RGBA');p=im.load();w,h=im.size;q=deque();seen=set()
 def add(x,y):
  if (x,y) not in seen and p[x,y][:3] in colors:
   seen.add((x,y));q.append((x,y))
 for x in range(w):add(x,0);add(x,h-1)
 for y in range(h):add(0,y);add(w-1,y)
 while q:
  x,y=q.popleft();p[x,y]=(0,0,0,0)
  for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   if 0<=nx<w and 0<=ny<h:add(nx,ny)
 return im

def remove_reviewed_background(im, colors):
 """Exact palette keys reviewed as sheet background, including enclosed gaps.
 Do not use this with guessed colors: flesh, linework, clothes and effects retain
 all non-key pixels. The generic flood_remove stays conservative for other uses.
 """
 im=im.convert('RGBA');px=im.load();removed=0
 for y in range(im.height):
  for x in range(im.width):
   c=px[x,y]
   if c[3] and c[:3] in colors:
    px[x,y]=(0,0,0,0);removed+=1
 return im,removed


def body_core(im):
 b=im.getbbox();px=im.load();h=b[3]-b[1];pts=[]
 for y in range(b[1]+int(h*.42),b[1]+int(h*.67)):
  runs=[];start=None
  for x in range(b[0],b[2]+1):
   opaque=x<b[2] and px[x,y][3]>0
   if opaque and start is None:start=x
   if start is not None and not opaque:runs.append((start,x));start=None
  if not runs:continue
  a,z=max(runs,key=lambda r:r[1]-r[0]);length=z-a
  if length>=4:pts.append(((a+z-1)/2,y,length**2))
 assert pts
 return [sum(v[k]*v[2] for v in pts)/sum(v[2] for v in pts) for k in [0,1]]

def main():
 a=json.loads((ROOT/'data/sprite_audit.json').read_text(encoding='utf8'));review=ROOT/'assets/sprite_processed/review';review.mkdir(parents=True,exist_ok=True)
 summary=[];cleanup=[]
 for index,(cid,rows,bg) in CONFIG.items():
  rec=next(r for r in a['sheets'] if r['index']==index);rec['character_id']=cid;source=ROOT/'assets/sprite_source'/rec['source_file'];digest=hashlib.sha256(source.read_bytes()).hexdigest();assert digest==rec['sha256']
  im=Image.open(source).convert('RGBA');dest=ROOT/'assets/sprite_processed'/cid;dest.mkdir(parents=True,exist_ok=True)
  profile={'id':cid,'source':rec['source_file'],'source_sha256':digest,'default_facing':'right' if index<49 or index in [64,66] else 'left','scale':2,'canvas':[240,120],'pivot':[120,100],'attack_impact_frame':IMPACT_FRAMES[index],'approach_seconds':0.24,'return_seconds':0.22,'hit_pause_seconds':0.08,'animations':{},'notes':[], 'background_removal':'EXACT_REVIEWED_SHEET_KEYS_INCLUDING_ENCLOSED_GAPS'}
  if index==64:profile['notes'].append('Original basic Y Combo; one battle impact despite the multi-pose animation.')
  if index==66:profile['notes'].append('User-selected alternate GitHub sheet kurenai_sprite.png, replacing the wrapped-dress sheet. Basic three-pose palm strike only; no flower effects. KO ends lying down.')
  if index in [52,53]:profile['notes'].append('Move uses idle + Tween: no verified running row.')
  if index==62:profile['notes'].append('Ordinary iron-ball swing only; chain/throw skill not implemented.')
  sheet=Image.new('RGBA',(max(1200,max(len(r[2])-1 for r in rows)*145),5*180),(20,27,36,255));d=ImageDraw.Draw(sheet)
  state_rows=list(zip(STATES,rows))
  if index in RANGED_ROWS:state_rows.append(('ranged_attack',RANGED_ROWS[index]))
  for si,(state,(y,h,xs)) in enumerate(state_rows):
   # Main-character knocked-back rows begin flat then tumble: reverse to end flat.
   cells=[(xs[j],y,xs[j+1]-xs[j],h) for j in range(len(xs)-1)]
   if state=='ko' and index<49:cells=cells[::-1]
   frames=[]
   colors={bg,(0,128,128),(0,255,255)}
   # Flail sheet changes its frame background between rows, both explicitly listed.
   if index==62:colors.add((48,200,152))
   if index==16:
    colors={((32,248,0) if state=='idle' else (0,120,0) if state=='hit' else (0,128,0)),(0,128,128)}
   # A planted/toe foot changes sides during a stride. Register the torso,
   # not whichever toe/weapon is lowest. Preserve original limb motion around it.
   body_cores=[];core_ground_distance=None
   if state in ['idle','move']:
    distances=[]
    for x,cy,w,ch in cells:
     sample,_=remove_reviewed_background(im.crop((x,cy,x+w,cy+ch)),colors)
     c=body_core(sample);body_cores.append(c)
     ground=66 if index==53 else sample.getbbox()[3]
     distances.append(ground-c[1])
    core_ground_distance=round(median(distances))
   for j,(x,cy,w,ch) in enumerate(cells):
    source_cell=im.crop((x,cy,x+w,cy+ch))
    conservative=flood_remove(source_cell,colors)
    remaining=sum(1 for c in conservative.get_flattened_data() if c[3] and c[:3] in colors)
    clean,removed=remove_reviewed_background(source_cell,colors)
    assert all(c[3]==0 or c[:3] not in colors for c in clean.get_flattened_data()),(cid,state,j,'background residue')
    assert all(after==before for before,after in zip(source_cell.get_flattened_data(),clean.get_flattened_data()) if before[3] and before[:3] not in colors),(cid,state,j,'foreground changed')
    if remaining:cleanup.append({'id':cid,'state':state,'frame':j,'enclosed_pixels_removed':remaining})
    bbox=clean.getbbox();assert bbox,(cid,state,j)
    # Foot anchor: center of lowest opaque pixels; weapons remain at original offsets.
    bottom=bbox[3]-1;px=clean.load()
    if index==53 and state in ['idle','move']:
     # Staff tip lies below boots: use body/boots, not the red staff, as the floor anchor.
     body_pixels=[(xx,yy) for yy in range(ch) for xx in range(20,w) if px[xx,yy][3]]
     bottom=max(yy for xx,yy in body_pixels)
    feet=[xx for yy in range(max(bbox[1],bottom-2),bottom+1) for xx in range(w) if px[xx,yy][3]]
    pivot_x=(min(feet)+max(feet))//2
    if index==53:
     # Reviewed boots/body centre. The diagonally held staff extends below boots;
     # trailing foot alone also cannot define the body's horizontal root.
     if state in ['idle','move']:pivot_x,bottom=50,65
     elif state=='attack':pivot_x,bottom=[88,88,86,86][j],58
     elif state=='hit':pivot_x,bottom=27,57
    if state in ['idle','move']:
     pivot_x=round(body_cores[j][0])
     bottom=round(body_cores[j][1])+core_ground_distance-1
    canvas=Image.new('RGBA',(240,120));offset=(120-pivot_x,100-bottom-1);canvas.alpha_composite(clean,offset)
    assert sum(c[3]>0 for c in canvas.get_flattened_data()) == sum(c[3]>0 for c in clean.get_flattened_data()), (cid,state,j,'opaque pixels clipped by alignment')
    assert canvas.getbbox()[0]>0 and canvas.getbbox()[2]<240 and canvas.getbbox()[1]>0, (cid,state,j,'canvas clips')
    name=f'{state}_{j:02}.png';canvas.save(dest/name)
    frames.append({'path':f'res://assets/sprite_processed/{cid}/{name}','source_rect':[x,cy,w,ch],'source_foot':[pivot_x,bottom+1],'bbox':list(bbox)})
    if state in ['idle','move']:
     frames[-1]['source_body_core']=body_cores[j]
     frames[-1]['registered_body_core']=[body_cores[j][0]+offset[0],body_cores[j][1]+offset[1]]
     assert abs(frames[-1]['registered_body_core'][0]-120)<=0.51
     assert abs(frames[-1]['registered_body_core'][1]-(100-core_ground_distance))<=0.51
    if si<5:
     small=canvas.crop((60,0,180,120));sheet.alpha_composite(small, (j*145,si*180+28))
   profile['animations'][state]={'fps':5 if state=='idle' else (12 if state in ['attack','move'] else 9),'loop':state in ['idle','move'],'frames':frames,'background_colors':[list(c) for c in sorted(colors)]}
   if si<5:d.text((4,si*180+6),cid+' / '+state,fill='white')
  # Breathing/guard poses are an open sequence, not a cyclic run. Walk back
  # through the intermediates instead of snapping from the last pose to the first.
  for st in ['idle'] + (['move'] if index in [52,53] else []):
   anim=profile['animations'][st];n=len(anim['frames'])
   anim['playback_order']=list(range(n))+list(range(n-2,0,-1))
   anim['fps']=7 if st=='idle' else 9
  profile['move_uses_stance']=index in [52,53]
  idle_frames=profile['animations']['idle']['frames']
  body_height=54 if index==53 else max(f['bbox'][3]-f['bbox'][1] for f in idle_frames)
  profile['scale']=round(min(2.0,96.0/body_height),4)
  profile['alignment']='TORSO_REGISTERED_IDLE_AND_MOVE_WITH_FIXED_BODY_HEIGHT'
  if index in RANGED_ROWS:profile['animations']['ranged_attack']['default_facing']='left';profile['ranged_impact_frame']=1 if index in [4,48,43] else 2
  used={Path(f['path']).name for v in profile['animations'].values() for f in v['frames']}
  for old in dest.glob('*.png'):
   if old.name not in used:
    assert old.resolve().is_relative_to(dest.resolve());old.unlink()
    importer=Path(str(old)+'.import')
    if importer.exists():importer.unlink()
  (ROOT/'data/sprite_profiles'/f'{cid}.json').write_text(json.dumps(profile,ensure_ascii=False,indent=2),encoding='utf8');sheet.convert('RGB').save(review/f'{cid}.png')
  assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
  summary.append({'id':cid,'frames':sum(len(s['frames']) for s in profile['animations'].values())})
 # Regression: conservative general flood fill still protects unreviewed enclosed colors.
 # Reviewed-key removal clears true holes but preserves nearby clothing shades and outlines.
 hole=Image.new('RGBA',(7,7),(0,128,0,255));ImageDraw.Draw(hole).rectangle((1,1,5,5),outline='black');hole.putpixel((2,2),(0,120,0,255))
 checked,_=remove_reviewed_background(hole,{(0,128,0)})
 assert checked.getpixel((3,3))[3]==0 and checked.getpixel((2,2))==(0,120,0,255) and checked.getpixel((1,1))==(0,0,0,255)
 # Regression: enclosed background-colored clothing must survive, only edge connected color removed.
 test=Image.new('RGBA',(7,7),(48,200,152,255));ImageDraw.Draw(test).rectangle((1,1,5,5),outline='black');out=flood_remove(test,{(48,200,152)})
 assert out.getpixel((0,0))[3]==0 and out.getpixel((3,3))[3]==255
 for record in a['sheets']:
  assert hashlib.sha256((ROOT/'assets/sprite_source'/record['source_file']).read_bytes()).hexdigest()==record['sha256']
  profile_path=ROOT/'data/sprite_profiles'/f"{record['character_id']}.json"
  if profile_path.exists():
   data=json.loads(profile_path.read_text(encoding='utf8'));record['confidence']='BASIC_ANIMATIONS_MANUALLY_REVIEWED';record['default_facing_candidate']=data['default_facing'];record['facing_note']='Default and animation-specific facing inspected in processed frames and live stage.';record['usability']='APPLIED_BASIC_SPRITES';record['visual_review']='INDIVIDUAL_BASIC_FRAMES_AND_LIVE_BATTLE';record['application_status']='APPLIED_REVIEWED_BASIC_ANIMATIONS';record['profile']=f"res://data/sprite_profiles/{record['character_id']}.json"
   for old,new in [('idle','idle'),('move','move'),('basic_attack','attack'),('hit','hit'),('ko','ko')]:
    record['animations'][old]=dict(data['animations'][new],mapping_finalized=True,status='APPLIED_IDLE_TWEEN_FALLBACK' if new=='move' and record['index'] in [52,53] else 'APPLIED',confidence='MANUAL_BASIC_POSE_REVIEW')
  else:record['application_status']='REPLACED_BY_USER_REQUEST' if record['index']==65 else 'NOT_APPLIED_MAPPING_UNCONFIRMED'
 (ROOT/'data/sprite_audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2),encoding='utf8')
 (ROOT/'data/sprite_background_cleanup.json').write_text(json.dumps({'profiles':len(summary),'frames':sum(x['frames'] for x in summary),'affected_frames':len(cleanup),'enclosed_pixels_removed':sum(x['enclosed_pixels_removed'] for x in cleanup),'corrections':cleanup,'sheet_fragment_fix':'generic_scythe hit and ko row bounds exclude adjacent poses'},indent=2),encoding='utf8')
 (review/'processing_report.json').write_text(json.dumps(summary,indent=2),encoding='utf8');print(f'PASS: {len(summary)} profiles, source hashes intact, enclosed-color regression passed.',summary)
if __name__=='__main__':main()
