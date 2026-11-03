/* Animierte Strichfigur je Übung. Pose: [Rumpf, OA1,UA1, OA2,UA2, OS1,US1, OS2,US2]
   Winkel in Grad: 0 = nach unten, 90 = nach vorne/rechts, 180 = nach oben, -90 = nach hinten/links */
const P={
 st:[180,0,0,0,0,0,0,0,0], stG:[180,25,165,25,165,0,0,0,0], sq:[150,60,160,60,160,85,-10,85,-10],
 lunT:[180,0,0,0,0,40,-15,-35,-90], lunB:[180,0,0,0,0,85,5,-10,-85],
 rdl:[95,0,0,0,0,10,0,-80,-85], spl1:[120,0,90,0,90,-60,-60,-62,-62], spl2:[103,0,90,0,90,-77,-77,-79,-79],
 nor1:[180,90,90,90,90,0,-90,0,-90], nor2:[125,110,110,110,110,-55,-90,-55,-90], toe:[180,0,0,0,0,0,0,0,0],
 lat1:[175,40,40,-40,-40,25,0,-25,0], lat2:[160,60,60,20,20,60,-15,-50,-50],
 pu1:[96,0,0,0,0,-84,-84,-86,-86], pu2:[92,-45,35,-45,35,-88,-88,-89,-89],
 row1:[130,0,0,0,0,20,-10,20,-10], row2:[130,-70,40,-70,40,20,-10,20,-10],
 oh1:[180,20,170,20,170,0,0,0,0], oh2:[180,178,180,178,180,0,0,0,0],
 pa1:[180,40,110,40,110,10,-5,10,-5], pa2:[180,90,90,90,90,10,-5,10,-5],
 db1:[90,180,180,180,180,180,90,180,90], db2:[90,95,95,180,180,180,90,-95,-95],
 yt1:[92,100,100,100,100,-90,-90,-90,-90], yt2:[92,150,150,150,150,-90,-90,-90,-90],
 cr:[150,-45,-45,-45,-45,70,-15,70,-15], up:[180,175,180,175,180,0,0,0,0],
 sk1:[160,40,40,-60,-60,-15,-10,25,-70], sk2:[200,60,60,-40,-40,15,10,-25,70],
 mb1:[170,-60,-60,-50,-50,15,0,-15,0], mb2:[195,80,80,70,70,15,0,-15,0],
 gk:[160,60,100,60,100,40,-15,-40,15], fly:[75,80,80,75,75,-95,-95,-105,-105],
 r1:[165,40,100,-40,10,55,-35,-30,-70], r2:[165,-40,10,40,100,-30,-70,55,-35],
 sh1:[175,60,90,60,90,30,10,-30,-10], sh2:[175,60,90,60,90,15,0,-45,-25],
 ca1:[175,80,120,80,120,25,0,-25,0], ca2:[175,100,100,100,100,25,0,-25,0],
 dr2:[120,30,20,30,20,60,-20,60,-20],
 se1:[170,0,0,0,0,90,90,-90,-90], se2:[205,60,60,-60,-60,90,90,-90,-90],
 fr1:[95,0,90,0,90,0,-90,0,-90], fr2:[78,10,100,10,100,45,-90,45,-90],
 cou1:[180,0,0,0,0,90,0,-10,-170], cou2:[190,-20,-20,-20,-20,90,0,-5,-170],
 pg1:[180,0,0,0,0,90,0,-90,-90], pg2:[115,60,60,60,60,90,0,-90,-90],
 co1:[170,90,90,90,90,60,-10,-60,-60], co2:[190,90,90,90,90,60,60,-60,10],
 ob1:[90,180,180,180,180,-45,-135,-45,-135], ob2:[90,180,180,-90,-90,-45,-135,-45,-135],
 di1:[150,150,150,150,150,0,0,0,0], di2:[150,210,210,210,210,0,0,0,0],
 hm1:[180,0,0,0,0,90,90,0,0], hm2:[125,85,85,85,85,90,90,0,0],
 wg1:[140,0,0,0,0,85,0,-60,-60], wg2:[160,180,180,0,0,85,0,-60,-60],
 an1:[180,0,0,0,0,90,0,0,-90], an2:[180,0,0,0,0,105,25,0,-90],
 th1:[120,90,90,90,90,-150,5,-150,5], th2:[90,90,90,90,90,-100,0,-100,0],
 lp1:[180,175,180,175,180,90,0,90,0], lp2:[180,30,150,30,150,90,0,90,0],
 ad1:[180,0,0,0,0,45,45,-45,-45], ad2:[180,0,0,0,0,8,8,-8,-8],
 bp1:[-130,90,90,90,90,155,45,155,45], bp2:[-130,90,90,90,90,115,115,115,115],
};
// Übung → [Pose A, Pose B, Sprunghöhe, Dauer in s]
const A={gob:['stG','sq',0,3],bss:['lunT','lunB',0,3],rdl:['st','rdl',0,3.4],cop:['spl1','spl2',0,3],side:['spl1','spl2',0,3],
 nord:['nor1','nor2',0,4],calf:['st','toe',8,2],lat:['lat1','lat2',0,3],push:['pu1','pu2',0,2.4],row:['row1','row2',0,2.4],
 ohp:['oh1','oh2',0,2.6],pall:['pa1','pa2',0,2.6],dead:['db1','db2',0,3],ytw:['yt1','yt2',0,2.6],cmj:['cr','up',28,1.8],
 box:['cr','up',22,1.8],latb:['sk1','sk2',10,1.6],mbt:['mb1','mb2',0,1.6],dive:['gk','fly',18,2.2],spr:['r1','r2',4,.6],
 ladder:['r1','r2',3,.4],shuf:['sh1','sh2',4,.8],wall:['ca1','ca2',0,.8],drop:['ca1','dr2',0,1.6],w90:['se1','se2',0,3.4],
 frog:['fr1','fr2',0,4],couch:['cou1','cou2',0,4],pige:['pg1','pg2',0,4],cosk:['co1','co2',0,3.4],tsp:['ob1','ob2',0,3.4],
 shd:['di1','di2',0,2.6],ham:['hm1','hm2',0,4],wgs:['wg1','wg2',0,3.4],ank:['an1','an2',0,2.6],jog:['r1','r2',5,.8],
 int:['r1','r2',6,.5],thrust:['th1','th2',0,2.6],lpull:['lp1','lp2',0,2.6],add:['ad1','ad2',0,2.6],legp:['bp1','bp2',0,2.6]};
const L={t:38,ua:20,fa:19,th:26,sh:26},V=a=>[Math.sin(a*Math.PI/180),Math.cos(a*Math.PI/180)];
function joints(p){const h=[0,0],add=(o,a,l)=>{const v=V(a);return[o[0]+v[0]*l,o[1]+v[1]*l]};
 const s=add(h,p[0],L.t),nk=add(s,p[0],4),hd=add(s,p[0],14);
 const e1=add(s,p[1],L.ua),w1=add(e1,p[2],L.fa),e2=add(s,p[3],L.ua),w2=add(e2,p[4],L.fa);
 const k1=add(h,p[5],L.th),f1=add(k1,p[6],L.sh),k2=add(h,p[7],L.th),f2=add(k2,p[8],L.sh);
 return{h,s,nk,hd,e1,w1,e2,w2,k1,f1,k2,f2}}
const ln=(p,q,c,w)=>`<line x1="${p[0].toFixed(1)}" y1="${p[1].toFixed(1)}" x2="${q[0].toFixed(1)}" y2="${q[1].toFixed(1)}" class="${c}" stroke-width="${w}"/>`;
const rc=(x,y,w,h,c,r=2)=>`<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w}" height="${h}" rx="${r}" class="${c}"/>`;
const ci=(p,r,c)=>`<circle cx="${p[0].toFixed(1)}" cy="${p[1].toFixed(1)}" r="${r}" class="${c}"/>`;
const mid=(a,b)=>[(a[0]+b[0])/2,(a[1]+b[1])/2];
const DB=p=>rc(p[0]-8,p[1]-1.5,16,3,'eq',1)+rc(p[0]-10,p[1]-5,4,10,'eq',1.5)+rc(p[0]+6,p[1]-5,4,10,'eq',1.5);
const GR=152;
function bench(p,w=46){return rc(p[0]-w/2,p[1],w,6,'eq2',2)+rc(p[0]-w/2+4,p[1]+6,3,GR-p[1]-6,'eq2',1)+rc(p[0]+w/2-7,p[1]+6,3,GR-p[1]-6,'eq2',1)}
// Geräte hinter (bg) und vor (fg) der Figur
function props(k,j){let bg='',fg='';
 switch(k){
 case'db1':fg=DB(mid(j.w1,j.w2));break;
 case'db2':bg=DB(j.w2);fg=DB(j.w1);break;
 case'bbS':fg=ci([j.s[0]-3,j.s[1]+2],12,'eq')+ci([j.s[0]-3,j.s[1]+2],3,'bg');break;
 case'bbH':fg=ci(mid(j.w1,j.w2),12,'eq')+ci(mid(j.w1,j.w2),3,'bg');break;
 case'benchB':bg=bench([j.f2[0]-4,j.f2[1]+3]);break;
 case'benchF':bg=bench([j.f1[0]+4,j.f1[1]+3]);break;
 case'thrust':bg=bench([j.s[0]+8,j.s[1]+4],34);fg=ci([j.h[0],j.h[1]-11],12,'eq')+ci([j.h[0],j.h[1]-11],3,'bg');break;
 case'pad':fg=rc(j.f1[0]-9,j.f1[1]-9,18,8,'eq2',4);bg=rc(10,GR-3,180,3,'mat',1.5);break;
 case'step':bg=rc(j.f1[0]-14,j.f1[1]+2,30,GR-j.f1[1]-2,'eq2',2);break;
 case'mat':bg=rc(12,GR-3,176,4,'mat',2);break;
 case'band':bg=rc(186,GR-90,5,90,'eq2',2)+`<line x1="${mid(j.w1,j.w2)[0]}" y1="${mid(j.w1,j.w2)[1]}" x2="188" y2="${mid(j.w1,j.w2)[1]}" class="cab" stroke-width="2.5"/>`;break;
 case'cable':bg=rc(182,GR-120,12,120,'eq2',3)+`<line x1="${mid(j.w1,j.w2)[0]}" y1="${mid(j.w1,j.w2)[1]}" x2="182" y2="${mid(j.w1,j.w2)[1]}" class="cab" stroke-width="1.5"/>`;break;
 case'lat':{const m=mid(j.w1,j.w2);bg=rc(j.h[0]-12,j.h[1]+2,26,6,'eq2',2)+rc(j.h[0]-1,j.h[1]+8,4,GR-j.h[1]-8,'eq2',1)+rc(m[0]-30,4,60,6,'eq2',2)+`<line x1="${m[0]}" y1="10" x2="${m[0]}" y2="${m[1]}" class="cab" stroke-width="1.5"/>`;fg=rc(m[0]-26,m[1]-2,52,4,'eq',2);break}
 case'sled':bg=rc(j.h[0]-26,j.h[1]-4,30,8,'eq2',3);fg=rc(j.f1[0]-2,j.f1[1]-16,6,32,'eq',2);break;
 case'box':bg=rc(132,GR-30,40,30,'eq2',4);break;
 case'cones':bg=`<path d="M22 ${GR}l7-14 7 14z" class="cone"/><path d="M164 ${GR}l7-14 7 14z" class="cone"/>`;break;
 case'ladder':bg=[20,48,76,104,132,160].map(x=>rc(x,GR-2,22,3,'cone',1)).join('');break;
 case'wall':bg=rc(184,10,10,GR-10,'eq2',2);if(j)fg='';break;
 case'ball':fg=ci([mid(j.w1,j.w2)[0]+4,mid(j.w1,j.w2)[1]-4],8,'ball');break;
 case'stick':fg=ln([j.w1[0]-16,j.w1[1]],[j.w1[0]+16,j.w1[1]],'eq',3.5);break;}
 return[bg,fg]}
let raf;
function playAnim(id,el,prop){cancelAnimationFrame(raf);const a=A[id];if(!a){el.innerHTML='';return false}
 el.innerHTML='<svg viewBox="0 0 200 165" class="fig"><ellipse id="sh" cx="100" cy="153" rx="30" ry="3" class="shadow"/><line x1="0" y1="152.5" x2="200" y2="152.5" class="floor"/><g id="fig" stroke-linecap="round" stroke-linejoin="round" fill="none"></g></svg>';
 const g=el.querySelector('#fig'),pa=P[a[0]],pb=P[a[1]],t0=performance.now(),raise=prop=='step'?10:prop=='benchF'&&/cop|side/.test(id)?0:0;
 (function f(now){const ph=(1-Math.cos(2*Math.PI*((now-t0)/1000)/a[3]))/2,p=pa.map((v,i)=>v+(pb[i]-v)*ph);
  const J=joints(p),pts=[J.h,J.s,J.e1,J.w1,J.e2,J.w2,J.k1,J.f1,J.k2,J.f2],my=Math.max(...pts.map(q=>q[1]),J.hd[1]+9);
  const lift=a[2]*Math.max(0,(ph-.55)/.45)+raise,T=q=>[100+q[0],GR-3-my+q[1]-lift],j={};for(const k in J)j[k]=T(J[k]);
  const [bg,fg]=props(prop,j);
  g.innerHTML=bg
   +ln(j.h,j.k2,'lb',11)+ln(j.k2,j.f2,'lb',9)+ln(j.f2,[j.f2[0]+6,j.f2[1]],'shoe2',6)+ln(j.s,j.e2,'lb',8)+ln(j.e2,j.w2,'lb',7)
   +ln(j.h,j.s,'shirt',17)+ln(j.nk,j.s,'skin',7)+ln(j.h,j.k1,'shorts',12)+ln(j.k1,j.f1,'skin',9.5)+ln(j.f1,[j.f1[0]+7,j.f1[1]],'shoe',6.5)
   +`<circle cx="${j.hd[0].toFixed(1)}" cy="${j.hd[1].toFixed(1)}" r="9" class="head"/>`
   +ln(j.s,j.e1,'shirt',8.5)+ln(j.e1,j.w1,'skin',7)+fg;
  el.querySelector('#sh').setAttribute('cx',j.h[0]);
  raf=requestAnimationFrame(f)})(t0);return true}
function stopAnim(){cancelAnimationFrame(raf)}
