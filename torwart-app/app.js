'use strict';
/* ---------- Daten ---------- */
const HOME={gob:'Goblet Squat mit Rucksack',ohp:'Pike Push-up',box:'Treppensprung'};
const GYMX={kraftA:['thrust','legp'],kraftB:['lpull','add']};
const T={
 kraftA:{n:'Kraft A',l:'Beine & Rumpf',i:'🦵',c:['#34C759','#0FA968'],cat:'Kraft',x:['gob','rdl','cop','lat','pall','side','calf'],w:'Absprungkraft und Stabilität.'},
 kraftB:{n:'Kraft B',l:'Oberkörper & Hüfte',i:'💪',c:['#0A84FF','#0055D4'],cat:'Kraft',x:['bss','nord','push','row','ohp','dead','ytw'],w:'Rücken und Schultern für Abwürfe, Oberschenkel schützen.'},
 explo:{n:'Explosivität',l:'Sprung & Antritt',i:'⚡️',c:['#FF9F0A','#FF6A00'],cat:'Explosiv',x:['wgs','cmj','latb','box','mbt','dive','spr'],w:'Ausgeruht machen, volle Pausen.'},
 react:{n:'Reaktion',l:'Hände & Füße',i:'🧤',c:['#BF5AF2','#8E3BD8'],cat:'Reaktion',x:['ladder','shuf','wall','drop','latb'],w:'Kurz und frisch – ideal vor dem Vereinstraining.'},
 mob:{n:'Beweglichkeit',l:'Hüfte & Schulter',i:'🧘',c:['#64D2FF','#2AA5D8'],cat:'Beweglichkeit',x:['ank','w90','cosk','frog','couch','pige','ham','tsp','shd'],w:'Mehr Reichweite bei Paraden, schnellere Regeneration.'},
 mobS:{n:'Aktivierung',l:'10 Minuten',i:'⏱️',c:['#5AC8FA','#30B0C7'],cat:'Beweglichkeit',x:['wgs','w90','cosk','tsp','ank'],w:'Vor dem Spiel oder als Aufwärmen.'},
 run:{n:'Lauf + Dehnen',l:'Grundlage',i:'🏃',c:['#FF375F','#D70F4A'],cat:'Ausdauer',x:['jog','frog','couch','ham'],w:'Grundlagenausdauer halten.'},
 gymA:{n:'Gym A',l:'Ganzkörper · Beine & Drücken',i:'🏋️',c:['#FF6B35','#D9431A'],cat:'Gym',x:['sqb','dbbench','row','rdlbb','latraise','plank'],w:'Grundübungen schwer und sauber. 90 s Pause, Gewicht steigern, wenn alle Wiederholungen klappen.'},
 gymB:{n:'Gym B',l:'Ganzkörper · Maschinen & Ziehen',i:'💪',c:['#5E5CE6','#3634A3'],cat:'Gym',x:['legp','lpull','incpress','lcurl','face','ccrunch'],w:'Gelenkschonend an Maschinen – ideal nach anstrengenden Diensten.'},
 gymC:{n:'Gym C',l:'Ganzkörper · Kraft & Puls',i:'🔥',c:['#00C7BE','#008F88'],cat:'Gym',x:['thrust','lunge','apull','ohp','tpush','hammer','mclimb'],w:'Etwas kürzere Pausen (60 s) – mehr Kalorienverbrauch.'},
 hiit:{n:'Spielnahe Ausdauer',l:'Intervalle',i:'🔥',c:['#FF453A','#C9201A'],cat:'Ausdauer',x:['wgs','int','spr','w90','cosk','tsp'],w:'Kurz, hart, wie im Spiel.'},
};
const GPLAN={2:{2:'kraftA',4:'kraftB'},3:{2:'kraftA',3:'explo',4:'kraftB'},4:{1:'mob',2:'kraftA',3:'explo',4:'kraftB'},5:{1:'mob',2:'kraftA',3:'explo',4:'kraftB',5:'react'}};
const FPLAN={2:['kraftA',0,0,'kraftB',0,0,0],3:['kraftA',0,'explo',0,'kraftB',0,0],4:['kraftA',0,'explo',0,'kraftB','mob',0],5:['kraftA','mob','explo',0,'kraftB','react',0]};
const GOALS={
 sprung:{n:'Sprungkraft',i:'🚀',d:'Höher springen, explosiver abdrücken',pri:['kraftA','explo','kraftB','mob','react'],test:'jump'},
 speed:{n:'Schnelligkeit',i:'⚡️',d:'Schneller reagieren und antreten',pri:['explo','react','kraftA','mob','kraftB'],test:'sprint'},
 kraft:{n:'Kraft & Athletik',i:'🏋️',d:'Stärker im Zweikampf und bei Paraden',pri:['kraftA','kraftB','explo','mob','kraftA'],test:'squat'},
 mobil:{n:'Beweglichkeit',i:'🧘',d:'Mehr Reichweite, tiefere Paraden',pri:['mob','kraftA','mob','kraftB','mobS'],test:'reach'},
 praev:{n:'Verletzungsschutz',i:'🛡️',d:'Leiste, Oberschenkel und Schultern stärken',pri:['kraftA','mob','kraftB','react','mob'],test:'plank'},
 gym:{n:'Gym & Abnehmen',i:'🏋️',d:'Muskeln aufbauen, Fett verlieren – 3er-Ganzkörperplan im Studio',pri:['gymA','gymB','gymC','mob','gymA'],test:'squat'},
 fit:{n:'Fitness & Ausdauer',i:'❤️',d:'90 Minuten fit und konzentriert',pri:['kraftA','hiit','kraftB','run','mob'],test:'cooper'}};
const TESTS={jump:{n:'Strecksprung',u:'cm',up:1,h:'Mit Kreide an der Wand: Reichhöhe stehend vs. gesprungen.'},sprint:{n:'5-m-Sprint',u:'s',up:0,h:'Aus der Grundstellung, Handy-Stoppuhr oder Partner.'},
 squat:{n:'Kniebeuge 5 Wdh.',u:'kg',up:1,h:'Höchstes Gewicht für 5 saubere Wiederholungen.'},reach:{n:'Sitz-Reichtest',u:'cm',up:1,h:'Beine gestreckt, Zentimeter über (+) oder vor (−) den Zehen.'},
 plank:{n:'Seitstütz',u:'s',up:1,h:'Maximale Haltezeit, schwächere Seite zählt.'},cooper:{n:'Cooper-Test 12 min',u:'m',up:1,h:'So weit wie möglich in 12 Minuten laufen (Strava!).'}};
const WD=['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'];
const WK=[{n:'Einstieg',s:0,r:0},{n:'Mehr Volumen',s:1,r:0},{n:'Mehr Intensität',s:1,r:2},{n:'Entlastung',s:-1,r:-2}];
const CATS=['Alle','Gym','Kraft','Explosiv','Reaktion','Beweglichkeit','Ausdauer'];
const DAY=864e5,WEEK=7*DAY;
const $=i=>document.getElementById(i);
const CH='<svg class="chev" viewBox="0 0 8 13"><path d="M1 1l5.5 5.5L1 12" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg>';

/* ---------- Verknüpfung mit dem Fitness-Coach ---------- */
const EMB=(()=>{try{return window.parent!==window}catch(e){return true}})();
const FC=(()=>{try{return EMB&&window.parent.fcBridge||null}catch(e){return null}})();
if(EMB)document.body.classList.add('embedded');
const iso=(ts=Date.now())=>{const d=new Date(ts);return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
const SHIFT={F:'Frei',F1:'Nach Nachtdienst',D:'Spätdienst',N:'Früh/Nacht'};
function fcDay(i){if(!FC)return null;try{const d=new Date(weekStart()+i*DAY+12*3600e3),ds=iso(+d);return{ds,kind:FC.dayKind(ds),shift:FC.shift(ds),run:FC.session(ds)}}catch(e){return null}}

/* ---------- Zustand ---------- */
const weekStart=(ts=Date.now())=>{const d=new Date(ts);d.setHours(0,0,0,0);d.setDate(d.getDate()-((d.getDay()+6)%7));return+d};
const dayKey=(ts=Date.now())=>{const d=new Date(ts);return d.getFullYear()+'-'+(d.getMonth()+1)+'-'+d.getDate()};
let S={goal:null,tests:[],chat:[],name:'Timo',game:6,days:3,eq:'gym',len:'normal',blockStart:weekStart(),log:[],ready:{},cur:null};
try{let o=JSON.parse(localStorage.getItem('gk2')||'null');if(!o&&FC){try{o=FC.loadGk()}catch(e){}}if(o)Object.assign(S,o);else{const old=JSON.parse(localStorage.getItem('gk')||'null');if(old){S.log=(old.log||[]).map(l=>({t:l.t,ts:l.ts,n:l.n,sets:{}}));['days','eq'].forEach(k=>old[k]!=null&&(S[k]=old[k]))}}}catch(e){}
if(S.goal&&!S.program)S.program={goal:S.goal,start:S.blockStart||Date.now(),weeks:0};
let fcT;const save=()=>{try{localStorage.setItem('gk2',JSON.stringify(S))}catch(e){}if(FC){clearTimeout(fcT);fcT=setTimeout(()=>{try{FC.saveGk(JSON.parse(JSON.stringify(S)))}catch(e){}},1200)}};
const wIdx=()=>((Math.floor((weekStart()-weekStart(S.blockStart))/WEEK)%4)+4)%4;

/* ---------- Hilfen ---------- */
function ex(id){const o=Object.assign({},X[id],S.eq=='gym'?GY[id]||{}:{});if(S.eq=='home'&&HOME[id])o.n=HOME[id];return o}
function dose(id,short){let[s,r,u]=X[id].d;const w=WK[wIdx()],c=catOf(id);
 if(S.goal=='kraft'&&c=='Kraft'&&!u){s++;r=Math.max(5,r-3)}
 if((S.goal=='sprung'||S.goal=='speed')&&(c=='Explosiv'||c=='Reaktion'))s++;
 if(S.goal=='mobil'&&c=='Beweglichkeit'&&u=='s')r+=15;
 if(S.goal=='praev'&&['nord','cop','side','ytw','pall','calf'].includes(id))s++;
 if(u!='min'){s=Math.max(1,s+w.s-(short?1:0));r=Math.max(1,r+(u=='s'?w.r*5:w.r))}
 return{s,r,u,timed:u=='s'||u=='min',sec:u=='min'?r*60:u=='s'?r:0,txt:`${s} × ${r}${u=='s'?' s':u=='min'?' min':''}`}}
function ids(t,short){let a=T[t].x.slice();if(S.eq=='gym'&&GYMX[t])a.splice(1,0,...GYMX[t]);if(short)a=a.slice(0,Math.ceil(a.length*.6));return a}
const catOf=id=>{for(const k of['kraftA','kraftB','explo','react','mob','run','hiit','gymA','gymB','gymC'])if(T[k].x.includes(id)||(GYMX[k]||[]).includes(id))return T[k].cat;return'Kraft'};
const restOf=id=>{const d=X[id].d,c=catOf(id);return d[2]=='min'?0:c=='Beweglichkeit'?15:d[2]=='s'?30:c=='Explosiv'?90:c=='Reaktion'?45:c=='Gym'?90:75};
const loaded=id=>!X[id].d[2]&&(catOf(id)=='Kraft'||catOf(id)=='Gym');
const mins=(t,short)=>Math.max(5,Math.round(ids(t,short).reduce((m,id)=>{const d=dose(id,short);return m+(d.u=='min'?d.s*d.r:d.s*((d.sec||40)+restOf(id))/60)},0)/5)*5);
const fmt=s=>Math.floor(s/60)+':'+String(Math.floor(s%60)).padStart(2,'0');
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function toast(m){const t=$('toast');t.textContent=m;t.classList.add('on');clearTimeout(t._t);t._t=setTimeout(()=>t.classList.remove('on'),2200)}
let actx;function beep(f=880,d=.15){try{actx=actx||new(window.AudioContext||window.webkitAudioContext)();const o=actx.createOscillator(),g=actx.createGain();o.frequency.value=f;o.connect(g);g.connect(actx.destination);g.gain.setValueAtTime(.25,actx.currentTime);g.gain.exponentialRampToValueAtTime(.001,actx.currentTime+d);o.start();o.stop(actx.currentTime+d)}catch(e){}}
const buzz=p=>{try{navigator.vibrate&&navigator.vibrate(p)}catch(e){}};

/* ---------- Plan ---------- */
function planFor(i){ // i = 0..6 (Mo..So)
 const g=GOALS[S.goal];
 if(!g)return S.game>=0&&(i-S.game+7)%7==0?'game':null;   // kein aktiver Plan: nur Spieltag anzeigen
 const pri=g.pri.slice(0,S.days);
 if(S.game<0){const slots=[0,4,2,5,1],k=slots.slice(0,S.days).indexOf(i);return k<0?null:pri[k]}
 const o=(i-S.game+7)%7;if(o==0)return'game';if(o==6)return'mobS';const k=[2,4,3,1,5].slice(0,S.days).indexOf(o);return k<0?null:pri[k]}
const doneOn=(t,i)=>S.log.some(l=>l.t==t&&l.ts>=weekStart()&&(new Date(l.ts).getDay()+6)%7==i);
const todayIdx=()=>(new Date().getDay()+6)%7;

/* ---------- Tagesform ---------- */
const RQ=[['sleep','Schlaf','😴'],['legs','Beine frisch','🦵'],['energy','Energie','⚡️']];
function readiness(){const r=S.ready[dayKey()];if(!r||RQ.some(q=>!r[q[0]]))return null;return RQ.reduce((a,q)=>a+r[q[0]],0)/RQ.length}
function renderReady(){const r=S.ready[dayKey()]||{},sc=readiness();
 $('rdyScore').textContent=sc==null?'':sc>=3.7?'🟢 Top':sc>=2.7?'🟡 Normal':'🔴 Müde';
 $('ready').innerHTML=RQ.map(([k,l,e])=>`<div class="q"><span>${e} ${l}</span><div class="dots">${[1,2,3,4,5].map(v=>`<button class="${r[k]==v?'on':''}" onclick="setReady('${k}',${v})">${v}</button>`).join('')}</div></div>`).join('')
  +(sc!=null&&sc<2.7?'<div class="hint" style="margin-top:10px">Du bist heute eher müde. Empfehlung: kurze Variante oder nur Beweglichkeit.</div>':'')}
function setReady(k,v){const d=dayKey();S.ready[d]=Object.assign(S.ready[d]||{},{[k]:v});save();renderReady();renderHero();buzz(8)}

/* ---------- Heute ---------- */
function fcLine(i){const f=fcDay(i);if(!f)return'';const p=[];if(f.shift)p.push('🗓 '+SHIFT[f.kind]);if(f.run)p.push((f.run.done?'✓ ':'🏃 ')+f.run.title+(f.run.km?' '+String(f.run.km).replace('.',',')+' km':''));return p.join(' · ')}
function renderHero(){const i=todayIdx(),t=planFor(i),sc=readiness(),fd=fcDay(i),night=fd&&fd.kind=='N',tired=(sc!=null&&sc<2.7)||night;let h;
 if(t=='game')h=`<div class="hero game"><div class="k">Spieltag</div><div class="n">⚽️ Heute ist Spiel</div><div class="m">Kein Training. 10 min Aktivierung als Aufwärmen.</div><div class="acts"><button onclick="startW('mobS',false)">Aktivierung starten</button></div></div>`;
 else if(t){const dn=doneOn(t,i);h=`<div class="hero" style="--hc:${T[t].c[0]}99"><div class="k">${dn?'✓ Erledigt':'Heute dran'}</div><div class="n">${T[t].i} ${T[t].n}</div><div class="m">${T[t].l} · ${ids(t,tired).length} Übungen · ca. ${mins(t,tired)} min</div>${fd?`<div class="m" style="margin-top:6px;opacity:.75">${fcLine(i)}${night?' – heute kurze Variante zwischen den Diensten':fd.kind=='D'?' – Training am Vormittag':''}</div>`:''}
  <div class="acts"><button onclick="startW('${t}',${tired})">${dn?'Nochmal':'Starten'}${tired?' (kurz)':''}</button><button class="gh" onclick="preview('${t}')">Details</button></div></div>`}
 else if(!S.goal){h=`<div class="hero rest"><div class="k">Kein aktiver Plan</div><div class="n">🎯 Freies Training</div><div class="m">Wähle einen Plan mit Ziel und Dauer – oder starte eine Einheit nach Lust und Laune.</div><div class="acts"><button onclick="pick=null;goalSheet()">Plan wählen</button><button class="gh" onclick="show('plan')">Einheiten</button></div></div>`}
 else{let nx=null;for(let k=1;k<7&&!nx;k++){const p=planFor((i+k)%7);if(p&&p!='game')nx=[(i+k)%7,p]}
  h=`<div class="hero rest"><div class="k">Ruhetag</div><div class="n">🛌 Erholung</div><div class="m">Nächste Einheit: ${nx?WD[nx[0]]+' · '+T[nx[1]].n:'–'}</div>${fd&&fcLine(i)?`<div class="m" style="margin-top:6px;opacity:.75">${fcLine(i)}</div>`:''}<div class="acts"><button onclick="startW('mob',true)">Lockeres Dehnen</button></div></div>`}
 $('hero').innerHTML=h}
/* ---------- Pläne (Ziel + Dauer, jederzeit beendbar) ---------- */
const DURS=[[4,'4 Wo.'],[8,'8 Wo.'],[12,'12 Wo.'],[0,'Offen']];
function progInfo(){const p=S.program;if(!p||!GOALS[p.goal])return null;
 const wk=Math.floor((weekStart()-weekStart(p.start))/WEEK)+1,units=S.log.filter(l=>l.ts>=p.start).length;
 const weeksSoFar=Math.max(1,Math.min(wk,p.weeks||wk)),adh=Math.min(100,Math.round(units/Math.max(1,S.days*weeksSoFar)*100));
 const g=GOALS[p.goal],ts=S.tests.filter(x=>x.k==g.test&&x.ts>=p.start-7*DAY);
 return{p,g,wk,units,adh,first:ts[0],last:ts[ts.length-1],done:p.weeks>0&&wk>p.weeks}}
function goalProgress(){const i=progInfo();return i?{g:i.g,adh:i.adh,first:i.first,last:i.last}:null}
function renderGoal(){const i=progInfo();
 if(!i){$('goalcard').innerHTML=`<button class="goal" onclick="goalSheet()"><div class="gi">🎯</div><div class="gb"><b>Kein aktiver Plan</b><small>Ziel und Dauer wählen – du kannst jederzeit beenden</small></div>${CH}</button>`;return}
 const tt=TESTS[i.g.test],dv=i.first&&i.last&&i.first!==i.last?i.last.v-i.first.v:null,good=dv!=null&&(tt.up?dv>0:dv<0);
 const pct=i.p.weeks?Math.min(100,Math.round(Math.min(i.wk,i.p.weeks)/i.p.weeks*100)):i.adh;
 $('goalcard').innerHTML=`<button class="goal" onclick="planSheet()"><div class="gi">${i.g.i}</div><div class="gb"><small>Aktiver Plan · ${i.p.weeks?`Woche ${Math.min(i.wk,i.p.weeks)} von ${i.p.weeks}`:`Woche ${i.wk} (offen)`}</small><b>${i.g.n}</b><small>${i.units} Einheiten · ${i.adh}% erledigt · ${tt.n}: ${i.last?i.last.v+' '+tt.u:'noch kein Test'}${dv!=null?` <span style="color:${good?'var(--ac)':'var(--red)'}">${dv>0?'+':''}${Math.round(dv*100)/100}</span>`:''}</small><div class="pbar" style="margin-top:6px"><i style="width:${pct}%;background:var(--ac)"></i></div></div>${CH}</button>`}
let pick=null,pickW=8;
function goalSheet(first){if(!pick)pick=S.goal||null;
 const active=progInfo();
 openSheet(first?'Willkommen! 👋':'Plan wählen',`${first?'<div class="sub" style="margin:0 0 14px">Was willst du verbessern? Plan, Übungen und Coach passen sich daran an. Du kannst den Plan jederzeit beenden.</div>':''}
 <div class="gpick">${Object.entries(GOALS).map(([k,g])=>`<button class="${pick==k?'on':''}" onclick="pick='${k}';goalSheet(${!!first})"><div class="e">${g.i}</div><b>${g.n}</b><span>${g.d}</span></button>`).join('')}</div>
 <div class="lbl">Dauer</div><div class="seg" id="g-dur"></div>
 <div class="lbl">Einheiten pro Woche</div><div class="seg" id="g-days"></div><div class="lbl">Spieltag</div><div class="seg" id="g-game"></div>
 <button class="btn" ${pick?'':'disabled style="opacity:.4"'} onclick="startProgram()">${active&&active.p.goal!==pick?'Aktuellen Plan beenden & neuen starten':active?'Plan übernehmen':'Plan starten'}</button>
 ${first?'<button class="btn sec" onclick="closeSheet()">Erst mal ohne Plan</button>':''}`);
 seg('g-dur',DURS,()=>pickW,v=>pickW=v);
 seg('g-days',[[2,'2'],[3,'3'],[4,'4'],[5,'5']],()=>S.days,v=>S.days=v);
 seg('g-game',[[-1,'—'],[0,'Mo'],[1,'Di'],[2,'Mi'],[3,'Do'],[4,'Fr'],[5,'Sa'],[6,'So']],()=>S.game,v=>S.game=v)}
function startProgram(){if(!pick)return;const cur=progInfo();
 if(cur&&cur.p.goal===pick){S.program.weeks=pickW;save();closeSheet();renderAll();toast('Plan angepasst');return}
 if(cur)archiveProgram(false);
 S.goal=pick;S.program={goal:pick,start:Date.now(),weeks:pickW};S.blockStart=weekStart();pick=null;save();closeSheet();renderAll();toast('Plan gestartet 💪')}
function archiveProgram(completed){const i=progInfo();if(!i)return null;
 const rec={goal:i.p.goal,start:i.p.start,end:Date.now(),weeks:i.p.weeks,units:i.units,adh:i.adh,completed,test:i.first&&i.last&&i.first!==i.last?{k:i.g.test,from:i.first.v,to:i.last.v}:null};
 (S.programs=S.programs||[]).push(rec);S.goal=null;S.program=null;save();return rec}
function planSheet(){const i=progInfo();if(!i)return goalSheet();
 const hist=(S.programs||[]).slice(-5).reverse();
 openSheet(i.g.i+' '+i.g.n,`<div class="pills" style="margin:0 0 14px"><span class="pill g">${i.p.weeks?`Woche ${Math.min(i.wk,i.p.weeks)} von ${i.p.weeks}`:`Woche ${i.wk}`}</span><span class="pill">seit ${new Date(i.p.start).toLocaleDateString('de-DE')}</span><span class="pill">${i.units} Einheiten</span><span class="pill">${i.adh}% erledigt</span></div>
 <div class="sub" style="margin:0 0 12px">${i.g.d}</div>
 <button class="btn" onclick="pick='${i.p.goal}';pickW=${i.p.weeks};goalSheet()">Plan ändern / anderes Ziel</button>
 <button class="btn red" onclick="if(confirm('Plan „${i.g.n}“ jetzt beenden? Deine Trainings bleiben gespeichert.')){showSummary(archiveProgram(false))}">Plan beenden</button>
 ${hist.length?`<div class="hd"><span>Frühere Pläne</span></div><div class="grp np">${hist.map(h=>`<div class="row"><div class="t">${GOALS[h.goal]?GOALS[h.goal].i+' '+GOALS[h.goal].n:h.goal}<div class="s">${new Date(h.start).toLocaleDateString('de-DE')} – ${new Date(h.end).toLocaleDateString('de-DE')} · ${h.units} Einheiten · ${h.adh}%${h.completed?' · ✓ abgeschlossen':' · beendet'}</div></div></div>`).join('')}</div>`:''}`)}
function showSummary(rec){if(!rec){closeSheet();renderAll();return}const g=GOALS[rec.goal]||{n:rec.goal,i:'🎯'},t=rec.test&&TESTS[rec.test.k];
 openSheet(rec.completed?'Plan geschafft! 🏆':'Plan beendet',`<div style="text-align:center;font-size:56px;margin:6px 0">${rec.completed?'🏆':'🏁'}</div>
 <div class="sum"><div><b>${Math.max(1,Math.round((rec.end-rec.start)/WEEK))}</b><span>Wochen</span></div><div><b>${rec.units}</b><span>Einheiten</span></div><div><b>${rec.adh}%</b><span>erledigt</span></div></div>
 ${t?`<div class="hint up">${t.n}: ${rec.test.from} → ${rec.test.to} ${t.u}</div>`:''}
 <div class="sub" style="margin:12px 0">${g.i} ${g.n} ist ${rec.completed?'abgeschlossen':'beendet'}. Bis du einen neuen Plan startest, trainierst du frei – alle Einheiten findest du unter „Training“.</div>
 <button class="btn" onclick="pick=null;goalSheet()">Neuen Plan wählen</button><button class="btn sec" onclick="closeSheet();renderAll()">Ohne Plan weiter</button>`);renderAll()}
function testSheet(){openSheet('Leistungstest',`<div class="grp np">${Object.entries(TESTS).map(([k,t])=>`<label class="row"><input type="radio" name="tk" value="${k}" ${GOALS[S.goal]&&GOALS[S.goal].test==k?'checked':''}><div class="t">${t.n}<div class="s">${t.h}</div></div><span class="v">${t.u}</span></label>`).join('')}</div>
 <div class="inputs" style="grid-template-columns:1fr"><div class="step"><label>Ergebnis</label><div class="sv" style="justify-content:center"><input id="tv" inputmode="decimal" placeholder="0" style="width:140px"></div></div></div>
 <button class="btn" onclick="addTest()">Speichern</button>`)}
function addTest(){const k=(document.querySelector('input[name=tk]:checked')||{}).value,v=parseFloat(($('tv').value||'').replace(',','.'));
 if(!k||isNaN(v))return toast('Bitte Test und Wert wählen');S.tests.push({k,v,ts:Date.now()});save();closeSheet();renderAll();renderStats();toast('✓ Test gespeichert')}
function renderTests(){const ks=Object.keys(TESTS).filter(k=>S.tests.some(x=>x.k==k));
 $('tests').innerHTML=ks.length?ks.map(k=>{const t=TESTS[k],a=S.tests.filter(x=>x.k==k),l=a[a.length-1],f=a[0],d=a.length>1?Math.round((l.v-f.v)*100)/100:null,g=d!=null&&(t.up?d>0:d<0);
  const mx=Math.max(...a.map(x=>x.v)),mn=Math.min(...a.map(x=>x.v)),sp=a.length>1?`<svg viewBox="0 0 60 20" style="width:60px;height:20px"><polyline fill="none" stroke="var(--ac)" stroke-width="2" points="${a.map((x,i)=>(i/(a.length-1)*58+1)+','+(19-(mx==mn?9:(x.v-mn)/(mx-mn)*18))).join(' ')}"/></svg>`:'';
  return `<div class="row"><div class="t">${t.n}<div class="s">${a.length} Messungen${d!=null?` · <span style="color:${g?'var(--ac)':'var(--red)'}">${d>0?'+':''}${d} ${t.u}</span>`:''}</div></div>${sp}<div class="v"><b>${l.v}</b> ${t.u}</div></div>`}).join(''):'<div class="row"><div class="t s">Miss alle 4 Wochen deinen Test – so siehst du, ob du deinem Ziel näherkommst.</div></div>'}

function renderToday(){const h=new Date().getHours();
 $('hello').textContent=(h<11?'Guten Morgen':h<18?'Hallo':'Guten Abend')+(S.name?', '+S.name:'');
 $('dateline').textContent=new Date().toLocaleDateString('de-DE',{weekday:'long',day:'numeric',month:'long'});
 $('wkname').textContent='Woche '+(wIdx()+1)+' · '+WK[wIdx()].n;
 renderHero();renderGoal();renderReady();const ti=todayIdx();
 $('week').innerHTML=WD.map((d,i)=>{const t=planFor(i),g=t=='game',dn=t&&!g&&doneOn(t,i);
  const ic=g?'<div class="ico" style="background:linear-gradient(140deg,#FF9F0A,#FF453A)">⚽️</div>':t?`<div class="ico" style="background:linear-gradient(140deg,${T[t].c[0]},${T[t].c[1]})">${T[t].i}</div>`:'<div class="ico" style="background:var(--fill)"></div>';
  return `<button class="row" ${t&&!g?`onclick="preview('${t}')"`:''}>${ic}<div class="t"><b style="font-weight:${i==ti?700:500}">${d}${i==ti?' · Heute':''}</b><div class="s">${g?'Spiel':t?T[t].n+' · '+T[t].l:'Ruhetag / Verein'}</div>${fcLine(i)?`<div class="s" style="font-size:12px">${fcLine(i)}</div>`:''}</div>${dn?'<span class="ok">✓</span>':t&&!g?CH:''}</button>`}).join('');
 $('note').innerHTML='<b>Auf dich abgestimmt:</b> Ziel: '+((GOALS[S.goal]||{}).n||'–')+'. Laut Strava läufst du regelmäßig 5–10 km (~6:20 /km), machst aber kaum Krafttraining. Deshalb Schwerpunkt Kraft, Sprungkraft und Beweglichkeit. Explosives nie am Tag nach dem Spiel, am Tag davor nur Aktivierung.'}

/* ---------- Training-Auswahl ---------- */
function renderPlan(){const sh=S.len=='short';
 $('tiles').innerHTML=Object.entries(T).map(([k,t])=>`<button class="tile" style="background:linear-gradient(140deg,${t.c[0]},${t.c[1]})" onclick="preview('${k}')"><div class="e">${t.i}</div><b>${t.n}</b><span>${t.l} · ${mins(k,sh)} min</span></button>`).join('')}
function preview(t){const sh=S.len=='short'||(readiness()!=null&&readiness()<2.7&&planFor(todayIdx())==t);
 openSheet(T[t].i+' '+T[t].n,`<div class="pills" style="margin:0 0 14px"><span class="pill g">${ids(t,sh).length} Übungen</span><span class="pill">ca. ${mins(t,sh)} min</span><span class="pill">${S.eq=='gym'?'🏋️ Studio':'🏠 Zuhause'}</span>${sh?'<span class="pill o">Kurz</span>':''}</div>
 <div class="sub" style="margin:0 0 12px">${T[t].w}</div><div class="grp">${ids(t,sh).map(id=>`<button class="row" onclick="detail('${id}')"><div class="stage" style="width:54px;padding:0;flex:none;box-shadow:none;background:var(--cell2)" data-mini="${id}"></div><div class="t">${ex(id).n}<div class="s">${dose(id,sh).txt}</div></div>${CH}</button>`).join('')}</div>
 <button class="btn" onclick="closeSheet();startW('${t}',${sh})">Training starten</button>`);
 document.querySelectorAll('[data-mini]').forEach(el=>{drawStill(el.dataset.mini,el)})}
const photoOf=id=>(S.eq=='gym'&&PHOTO[id+'_g'])||PHOTO[id]||null;
function showMedia(id,el){const ph=photoOf(id);if(!ph){el.classList.remove('ph');return playAnim(id,el,ex(id).p)}stopAnim();
 el.classList.add('ph');el.innerHTML=`<img src="img/${ph}-0.jpg" alt="${esc(ex(id).n)} – Start"><img class="b" src="img/${ph}-1.jpg" alt="${esc(ex(id).n)} – Ende"><span class="lbl2">Start ⇄ Ende</span>`}
function drawStill(id,el){const ph=photoOf(id);if(ph){el.innerHTML=`<img src="img/${ph}-0.jpg" alt="" loading="lazy" style="width:100%;height:100%;object-fit:cover;display:block">`;el.style.height='54px';el.style.overflow='hidden';return}playAnim(id,el,ex(id).p);stopAnim()}

/* ---------- Übungen ---------- */
let cat='Alle';
function renderLib(){const q=$('q').value.trim().toLowerCase();
 const list=Object.keys(X).filter(id=>S.eq=='gym'||!(['thrust','lpull','add','legp'].includes(id)||catOf(id)=='Gym')).filter(id=>cat=='Alle'||catOf(id)==cat).filter(id=>!q||(ex(id).n+' '+ex(id).e).toLowerCase().includes(q)).sort((a,b)=>ex(a).n.localeCompare(ex(b).n,'de'));
 $('libcount').textContent=list.length+' Übungen mit Anleitung';
 $('cats').innerHTML=CATS.map(c=>`<button class="chip${c==cat?' on':''}" onclick="cat='${c}';renderLib()">${c}</button>`).join('');
 $('lib').innerHTML=list.map(id=>`<button class="row" onclick="detail('${id}')"><div class="stage" style="width:54px;padding:0;flex:none;box-shadow:none;background:var(--cell2)" data-mini="${id}"></div><div class="t">${ex(id).n}<div class="s">${catOf(id)} · ${esc(ex(id).e.split(/[,(]/)[0])}</div></div>${CH}</button>`).join('')||'<div class="row"><div class="t s">Nichts gefunden</div></div>';
 document.querySelectorAll('#lib [data-mini]').forEach(el=>drawStill(el.dataset.mini,el))}
$('q').oninput=renderLib;

function lastSets(id){for(let k=S.log.length-1;k>=0;k--){const s=S.log[k].sets&&S.log[k].sets[id];if(s&&s.length)return s}return null}
function bestKg(id){let b=0;S.log.forEach(l=>(l.sets&&l.sets[id]||[]).forEach(([kg])=>b=Math.max(b,kg||0)));return b}
function progression(id,short){const ls=lastSets(id),d=dose(id,short);if(!ls||!loaded(id))return null;const kg=Math.max(...ls.map(s=>s[0]||0));
 const hit=ls.length>=d.s&&ls.every(s=>s[1]>=d.r);return{kg,txt:`Letztes Mal: ${ls.map(s=>(s[0]?s[0]+' kg × ':'')+s[1]).join(', ')}`,up:hit&&kg?Math.round((kg*1.05)/1.25)*1.25:null}}

function detail(id){const e=ex(id),d=dose(id,S.cur&&S.cur.short),pr=progression(id),b=bestKg(id);
 openSheet(e.n,`<div class="stage" id="anim"></div>
 <div class="pills"><span class="pill g">${d.txt}</span><span class="pill">Pause ${restOf(id)} s</span><span class="pill">${catOf(id)}</span>${b?`<span class="pill o">Bestwert ${b} kg</span>`:''}</div>
 ${pr?`<div class="hint${pr.up?' up':''}">${pr.txt}${pr.up?`<br>↑ Bereit für ${pr.up} kg`:''}</div>`:''}
 <div class="hd"><span>Ausrüstung</span></div><div class="grp"><div class="note"><div class="ico" style="background:var(--eq2)">🏋️</div><div>${esc(e.e)}</div></div></div>
 <div class="hd"><span>So geht's</span></div><div class="grp"><ol class="steps">${e.s.split('|').map((s,i)=>`<li><i>${i+1}</i><span>${esc(s)}</span></li>`).join('')}</ol></div>
 <div class="hd"><span>Achte auf</span></div><div class="grp"><div class="note"><div class="ico" style="background:var(--orange)">!</div><div>${esc(e.f)}</div></div></div>
 <div class="hd"><span>Warum als Torwart</span></div><div class="grp"><div class="note"><div class="ico" style="background:var(--ac)">🧤</div><div>${esc(e.w)}</div></div></div>
 <a class="btn sec" target="_blank" rel="noopener" href="https://www.youtube.com/results?search_query=${encodeURIComponent(e.n+' Ausführung')}">▶ Video auf YouTube</a>${photoOf(id)?'<div class="credit">Fotos: Free Exercise DB (gemeinfrei)</div>':''}`);
 showMedia(id,$('anim'))}

/* ---------- Geführtes Training ---------- */
let W=null,tick=null,lock=null;
function startW(t,short){closeSheet();W={t,short:!!short,list:ids(t,short),i:0,set:1,sets:{},start:Date.now(),phase:'work',restEnd:0,workEnd:0};S.cur=W;save();openPlayer()}
function resumeW(){if(S.cur&&S.cur.list){W=S.cur;W.phase=W.phase=='done'?'done':'work';openPlayer()}}
async function openPlayer(){$('player').classList.add('on');document.body.style.overflow='hidden';
 try{lock=await navigator.wakeLock.request('screen')}catch(e){}
 clearInterval(tick);tick=setInterval(loop,250);renderP()}
function closePlayer(){$('player').classList.remove('on');document.body.style.overflow='';clearInterval(tick);stopAnim();try{lock&&lock.release()}catch(e){}lock=null;renderAll()}
function quitW(){if(confirm('Training beenden? Bisherige Sätze werden nicht gespeichert.')){S.cur=null;W=null;save();closePlayer()}}
function loop(){if(!W)return;const el=$('pElapsed');if(el)el.textContent=fmt((Date.now()-W.start)/1000);
 if(W.phase=='rest'){const l=Math.ceil((W.restEnd-Date.now())/1000);ringUpd(l,W.restLen);if(l<=3&&l>0&&W._b!=l){W._b=l;beep(660,.08)}if(l<=0){beep(990,.25);buzz([200,80,200]);W.phase='work';renderP()}}
 if(W.phase=='timed'){const l=Math.ceil((W.workEnd-Date.now())/1000);ringUpd(l,W.workLen);if(l<=3&&l>0&&W._b!=l){W._b=l;beep(660,.08)}if(l<=0){beep(990,.3);buzz([300,100,300]);logSet(null,dose(cur(),W.short).r)}}}
const cur=()=>W.list[W.i];
function ringUpd(l,tot){const t=$('rTxt'),a=$('rArc');if(!t)return;t.textContent=fmt(Math.max(0,l));a.setAttribute('stroke-dashoffset',(2*Math.PI*104)*(1-Math.max(0,l)/tot))}
function ring(col){const C=2*Math.PI*104;return `<svg class="big-ring" viewBox="0 0 240 240"><circle cx="120" cy="120" r="104" fill="none" stroke="var(--fill)" stroke-width="16"/><circle id="rArc" cx="120" cy="120" r="104" fill="none" stroke="${col}" stroke-width="16" stroke-linecap="round" transform="rotate(-90 120 120)" stroke-dasharray="${C}" stroke-dashoffset="0" style="transition:stroke-dashoffset .25s linear"/><text id="rTxt" x="120" y="134" text-anchor="middle" font-size="48"></text></svg>`}
function renderP(){const P=$('player');if(!W)return;
 if(W.phase=='done')return renderSummary();
 const id=cur(),e=ex(id),d=dose(id,W.short),pr=progression(id,W.short),done=W.sets[id]||[];
 const segs=W.list.map((x,k)=>`<i class="${k<W.i?'d':k==W.i?'c':''}"></i>`).join('');
 let body='';
 if(W.phase=='rest'){const nx=W.set<=d.s?`Satz ${W.set} von ${d.s} · ${e.n}`:W.list[W.i+1]?ex(W.list[W.i+1]).n:'';
  body=`<div style="text-align:center;margin-top:20px"><div class="setinfo">Pause</div>${ring('var(--blue)')}<div class="setinfo">Als Nächstes</div><div style="font-weight:700;font-size:20px;margin-top:4px">${nx}</div></div>
  <div style="display:flex;gap:10px;margin-top:auto"><button class="btn sec" style="flex:1" onclick="W.restEnd+=15000;W.restLen+=15">+15 s</button><button class="btn" style="flex:2" onclick="W.restEnd=Date.now()">Pause überspringen</button></div>`}
 else{const kgV=W._kg!=null?W._kg:(done.length?done[done.length-1][0]:pr?(pr.up||pr.kg):0),rV=d.r;
  body=`<div class="stage" id="pAnim"></div><h3>${e.n}</h3>
  <div class="setinfo">Satz <b>${Math.min(W.set,d.s)} von ${d.s}</b> · Ziel <b>${d.u=='s'?d.r+' s':d.u=='min'?d.r+' min':d.r+' Wdh.'}</b></div>
  ${pr?`<div class="hint${pr.up?' up':''}">${pr.txt}${pr.up?` → heute ${pr.up} kg probieren`:''}</div>`:''}
  ${done.length?`<div class="setlist">${done.map((s,k)=>`<span>✓ ${s[0]?s[0]+' kg × ':''}${s[1]}${d.timed?(d.u=='min'?' min':' s'):''}</span>`).join('')}</div>`:''}
  ${W.phase=='timed'?`<div style="text-align:center">${ring('var(--ac)')}</div><button class="btn sec" onclick="logSet(null,${d.r})">Fertig</button>`
   :d.timed?`<button class="btn" style="margin-top:auto" onclick="startTimed(${d.sec})">▶ Start ${d.u=='min'?d.r+' min':d.r+' s'}</button>`
   :`<div class="inputs">${loaded(id)?`<div class="step"><label>Gewicht kg</label><div class="sv"><button onclick="adj('pKg',-2.5)">−</button><input id="pKg" inputmode="decimal" value="${kgV}"><button onclick="adj('pKg',2.5)">+</button></div></div>`:''}
    <div class="step" ${loaded(id)?'':'style="grid-column:1/3"'}><label>Wiederholungen</label><div class="sv"><button onclick="adj('pR',-1)">−</button><input id="pR" inputmode="numeric" value="${rV}"><button onclick="adj('pR',1)">+</button></div></div></div>
    <button class="btn" style="margin-top:auto" onclick="logSet(${loaded(id)?"+$('pKg').value.replace(',','.')":'null'},+$('pR').value)">Satz erledigt ✓</button>`}
  <div class="pl-foot"><button onclick="move(-1)" ${W.i==0?'style="visibility:hidden"':''}>‹ Zurück</button><button onclick="detail('${id}')">Anleitung</button><button onclick="move(1)">Überspringen ›</button></div>`}
 P.innerHTML=`<div class="pl-top"><button class="x" onclick="quitW()">✕</button><div class="tt">${T[W.t].n}<small id="pElapsed">${fmt((Date.now()-W.start)/1000)}</small></div><button class="x" style="color:var(--blue);font-size:13px;width:auto;padding:0 12px;border-radius:15px" onclick="finishW()">Ende</button></div>
 <div class="segs">${segs}</div><div class="pl-body">${body}</div>`;
 if($('pAnim'))showMedia(id,$('pAnim'));else stopAnim();loop()}
function adj(i,v){const el=$(i);el.value=Math.max(0,Math.round(((+el.value.replace(',','.')||0)+v)*100)/100);if(i=='pKg')W._kg=+el.value;buzz(5)}
function startTimed(sec){W.phase='timed';W.workLen=sec;W.workEnd=Date.now()+sec*1000;beep(880,.12);renderP()}
function logSet(kg,reps){const id=cur(),d=dose(id,W.short);(W.sets[id]=W.sets[id]||[]).push([kg&&!isNaN(kg)?kg:0,reps||0]);if(kg)W._kg=kg;buzz(15);
 W.set++;const last=W.set>d.s;if(last){W.i++;W.set=1;W._kg=null}
 if(W.i>=W.list.length){W.phase='done';save();return renderP()}
 const r=restOf(last?W.list[W.i-1]:id);if(r>0){W.phase='rest';W.restLen=r;W.restEnd=Date.now()+r*1000}else W.phase='work';save();renderP()}
function move(k){W.i=Math.max(0,Math.min(W.list.length,W.i+k));W.set=(W.sets[W.list[W.i]]||[]).length+1;W.phase='work';W._kg=null;
 if(W.i>=W.list.length)W.phase='done';save();renderP()}
function finishW(){W.phase='done';renderP()}
function stats(w){let n=0,vol=0;Object.entries(w.sets).forEach(([id,s])=>s.forEach(([kg,r])=>{n++;vol+=(kg||0)*(r||0)}));return{n,vol:Math.round(vol)}}
function renderSummary(){stopAnim();const st=stats(W),dur=Math.round((Date.now()-W.start)/60000),exs=Object.keys(W.sets).length;
 $('player').innerHTML=`<div class="pl-top"><span style="width:30px"></span><div class="tt">Zusammenfassung</div><span style="width:30px"></span></div><div class="pl-body">
 <div style="text-align:center;font-size:64px;margin-top:20px">🏆</div><h3 style="text-align:center">Stark gemacht!</h3><div class="setinfo" style="text-align:center">${T[W.t].n} abgeschlossen</div>
 <div class="sum"><div><b>${dur}</b><span>Minuten</span></div><div><b>${st.n}</b><span>Sätze</span></div><div><b>${st.vol>=1000?(st.vol/1000).toFixed(1)+' t':st.vol+' kg'}</b><span>Volumen</span></div></div>
 <div class="setinfo">Wie anstrengend war's? (1 = locker, 10 = maximal)</div><div class="rpe">${[1,2,3,4,5,6,7,8,9,10].map(v=>`<button class="${W.rpe==v?'on':''}" onclick="W.rpe=${v};renderSummary()">${v}</button>`).join('')}</div>
 <button class="btn" style="margin-top:auto" onclick="saveW()">Speichern</button><button class="btn red" onclick="if(confirm('Verwerfen?')){S.cur=null;W=null;save();closePlayer()}">Verwerfen</button></div>`}
function saveW(){const st=stats(W);if(FC){try{const dur=Math.max(1,Math.round((Date.now()-W.start)/60000));FC.addWorkout({id:'gk'+W.start,d:iso(),type:'Torwart',min:dur,title:T[W.t].n})}catch(e){}}S.log.push({t:W.t,ts:Date.now(),dur:Math.round((Date.now()-W.start)/60000),n:Object.keys(W.sets).length,sets:W.sets,rpe:W.rpe||null,vol:st.vol});S.cur=null;W=null;save();closePlayer();show('stats');toast('✓ Training gespeichert')}

/* ---------- Statistik ---------- */
function renderStats(){const L=S.log,ws=weekStart(),wk=L.filter(l=>l.ts>=ws);
 const goal=S.days+(S.game<0?0:1);
 const mn=wk.reduce((a,l)=>a+(l.dur??30),0),mgoal=goal*40;let streak=0;
 for(let w=0;w<300;w++){const a=ws-w*WEEK;if(L.some(l=>l.ts>=a&&l.ts<a+WEEK))streak++;else if(w>0)break}
 const rg=(r,v,c)=>{const C=2*Math.PI*r;return `<circle cx="60" cy="60" r="${r}" fill="none" stroke="${c}" stroke-opacity=".2" stroke-width="12"/><circle cx="60" cy="60" r="${r}" fill="none" stroke="${c}" stroke-width="12" stroke-linecap="round" transform="rotate(-90 60 60)" stroke-dasharray="${C}" stroke-dashoffset="${C*(1-Math.min(1,v))}"/>`};
 $('rings').innerHTML=`<svg viewBox="0 0 120 120">${rg(52,wk.length/goal,'#FF375F')}${rg(38,mn/mgoal,'#30D158')}${rg(24,Math.min(streak,4)/4,'#0A84FF')}</svg>
 <div class="leg"><div><span style="color:#FF375F">Einheiten</span><b>${wk.length}/${goal}</b></div><div><span style="color:#30D158">Minuten</span><b>${mn}/${mgoal}</b></div><div><span style="color:#0A84FF">Serie</span><b>${streak} ${streak==1?'Woche':'Wochen'}</b></div></div>`;
 const vol=L.reduce((a,l)=>a+(l.vol||0),0),rp=L.filter(l=>l.rpe),avg=rp.length?(rp.reduce((a,l)=>a+l.rpe,0)/rp.length).toFixed(1):'–';
 $('kpis').innerHTML=`<div class="kpi"><span>Einheiten</span><b>${L.length}</b></div><div class="kpi"><span>Trainingszeit</span><b>${Math.round(L.reduce((a,l)=>a+(l.dur??30),0)/60*10)/10}<small> h</small></b></div><div class="kpi"><span>Bewegtes Gewicht</span><b>${(vol/1000).toFixed(1)}<small> t</small></b></div><div class="kpi"><span>Ø Anstrengung</span><b>${avg}<small> /10</small></b></div>`;
 const wks=[...Array(8)].map((_,k)=>{const a=ws-(7-k)*WEEK;return{c:L.filter(l=>l.ts>=a&&l.ts<a+WEEK).length,l:new Date(a).toLocaleDateString('de-DE',{day:'numeric',month:'numeric'})}}),mx=Math.max(goal,...wks.map(w=>w.c));
 $('chart').innerHTML=`<svg viewBox="0 0 320 150">${wks.map((w,k)=>{const h=w.c/mx*100,x=10+k*39;return `<rect x="${x}" y="${115-h}" width="26" height="${Math.max(h,2)}" rx="6" fill="${k==7?'var(--ac)':'var(--eq2)'}" opacity="${k==7?1:.55}"/><text x="${x+13}" y="${110-h}" text-anchor="middle" font-size="11" font-weight="700" fill="currentColor">${w.c||''}</text><text x="${x+13}" y="134" text-anchor="middle" font-size="10" fill="currentColor" opacity=".5">${w.l}</text>`}).join('')}<line x1="6" x2="314" y1="${115-goal/mx*100}" y2="${115-goal/mx*100}" stroke="#FF375F" stroke-dasharray="4 4" stroke-width="1.2"/></svg><div class="ft" style="margin:4px 0 0">Gestrichelt: dein Wochenziel (${goal})</div>`;
 const prs=Object.keys(X).map(id=>[id,bestKg(id)]).filter(p=>p[1]>0).sort((a,b)=>b[1]-a[1]);
 renderTests();
 $('prs').innerHTML=prs.length?prs.map(([id,kg])=>`<button class="row" onclick="detail('${id}')"><div class="t">${ex(id).n}</div><div class="v"><b style="color:var(--tx)">${kg}</b> kg</div>${CH}</button>`).join(''):'<div class="row"><div class="t s">Trage im Training Gewichte ein – hier erscheinen deine Bestwerte.</div></div>';
 $('log').innerHTML=L.length?L.slice(-30).reverse().map(l=>{const t=T[l.t]||{n:l.t,i:'',c:['#999','#777']};return `<div class="row"><div class="ico" style="background:linear-gradient(140deg,${t.c[0]},${t.c[1]})">${t.i}</div><div class="t">${t.n}<div class="s">${new Date(l.ts).toLocaleDateString('de-DE',{weekday:'short',day:'numeric',month:'short'})} · ${l.dur?l.dur+' min · ':''}${l.n} Übungen${l.rpe?' · RPE '+l.rpe:''}</div></div></div>`}).join(''):'<div class="row"><div class="t s">Noch keine Einheit – leg los!</div></div>'}

/* ---------- Profil ---------- */
function seg(id,opts,get,set){const el=$(id);el.innerHTML=opts.map(([v,l])=>`<button class="${get()==v?'on':''}">${l}</button>`).join('');
 [...el.children].forEach((b,k)=>b.onclick=()=>{set(opts[k][0]);save();seg(id,opts,get,set);renderAll();buzz(6)})}
function renderProf(){$('pName').value=S.name||'';$('pGoal').textContent=GOALS[S.goal]?GOALS[S.goal].i+' '+GOALS[S.goal].n:'Kein Plan';
 $('pGame').innerHTML=[[-1,'Kein fester Spieltag'],...WD.map((d,i)=>[i,d])].map(([v,l])=>`<option value="${v}"${S.game==v?' selected':''}>${l}</option>`).join('');
 seg('s-eq',[['gym','🏋️ Studio'],['home','🏠 Zuhause']],()=>S.eq,v=>S.eq=v);
 seg('s-days',[[2,'2'],[3,'3'],[4,'4'],[5,'5']],()=>S.days,v=>S.days=v);
 seg('s-week',[0,1,2,3].map(i=>[i,String(i+1)]),()=>wIdx(),v=>S.blockStart=weekStart()-v*WEEK);
 $('blockinfo').textContent=`Woche ${wIdx()+1}: ${WK[wIdx()].n}. Die Woche zählt automatisch weiter – nach Woche 4 (Entlastung) beginnt ein neuer Block.`}
$('pName').onchange=e=>{S.name=e.target.value.trim();save();renderAll()};
$('pGame').onchange=e=>{S.game=+e.target.value;save();renderAll()};
$('exp').onclick=()=>{const b=new Blob([JSON.stringify(S,null,1)],{type:'application/json'}),a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='torwart-backup-'+dayKey()+'.json';a.click();toast('Backup erstellt')};
$('imp').onchange=e=>{const f=e.target.files[0];if(!f)return;f.text().then(t=>{try{const o=JSON.parse(t);if(!Array.isArray(o.log))throw 0;S=Object.assign(S,o);save();renderAll();toast('Backup geladen')}catch(x){toast('Datei ungültig')}})};
$('reset').onclick=()=>{if(confirm('Wirklich alle Trainings und Einstellungen löschen?')){S.log=[];S.ready={};S.cur=null;save();renderAll();toast('Gelöscht')}};
const lenSeg=()=>seg('s-len',[['normal','Normal'],['short','Kurz (~60 %)']],()=>S.len,v=>S.len=v);

/* ---------- Sheet / Navigation ---------- */
function openSheet(t,html){$('shT').textContent=t;$('shB').innerHTML=html;$('sheet').classList.add('open');document.querySelector('.sheet').scrollTop=0}
function closeSheet(){if(!$('sheet').classList.contains('open'))return;$('sheet').classList.remove('open');if(W&&$('player').classList.contains('on'))renderP();else stopAnim()}
let tab='today';
function show(t){tab=t;document.querySelectorAll('.tab').forEach(e=>e.classList.toggle('on',e.id=='t-'+t));document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('on',b.dataset.t==t));scrollTo(0,0);
 if(t=='plan')renderLib();if(t=='stats')renderStats();if(t=='coach')renderCoach()}
document.querySelectorAll('nav button').forEach(b=>b.onclick=()=>{show(b.dataset.t);buzz(5)});
function renderAll(){renderToday();renderPlan();lenSeg();renderProf();if(tab=='plan')renderLib();if(tab=='stats')renderStats();
 const c=$('resume');if(S.cur&&S.cur.list&&!$('player').classList.contains('on')){if(!c){const d=document.createElement('div');d.id='resume';d.innerHTML=`<button class="btn" style="margin:0 0 14px">▶ Training fortsetzen</button>`;d.onclick=resumeW;$('hero').before(d)}}else if(c)c.remove()}
/* ---------- KI-Coach ---------- */
let sampleFn,coachCtl,busy=false;
const QS=['Was soll ich heute trainieren?','Wie war meine Woche?','Mein Knie zwickt – was ersetze ich?','Wie werde ich bei Flanken sicherer?','Erstelle mir ein Aufwärmen vor dem Spiel','Wie steigere ich meine Sprungkraft?'];
function ctxData(){const ws=weekStart(),last=S.log.slice(-12).map(l=>({einheit:(T[l.t]||{}).n||l.t,datum:new Date(l.ts).toLocaleDateString('de-DE'),min:l.dur,rpe:l.rpe,saetze:Object.fromEntries(Object.entries(l.sets||{}).map(([id,s])=>[ex(id).n,s.map(x=>(x[0]?x[0]+'kg×':'')+x[1]).join(', ')]))}));
 return {name:S.name,ziel:(GOALS[S.goal]||{}).n||'kein aktiver Plan (freies Training)',plan:progInfo()?{woche:progInfo().wk,dauerWochen:progInfo().p.weeks||'offen',erledigtProzent:progInfo().adh}:null,fruererePlaene:(S.programs||[]).slice(-3).map(h=>(GOALS[h.goal]||{}).n+': '+h.units+' Einheiten, '+h.adh+'%'),einheitenProWoche:S.days,spieltag:S.game<0?'keiner':WD[S.game],ort:S.eq=='gym'?'Fitnessstudio':'Zuhause',
  blockwoche:(wIdx()+1)+' von 4 ('+WK[wIdx()].n+')',heute:WD[todayIdx()],plan:WD.map((d,i)=>d+': '+(planFor(i)=='game'?'Spiel':planFor(i)?T[planFor(i)].n:'frei')),
  tagesform:S.ready[dayKey()]||'nicht angegeben',dieseWoche:S.log.filter(l=>l.ts>=ws).length+' Einheiten',letzteEinheiten:last,
  tests:S.tests.slice(-10).map(x=>TESTS[x.k].n+': '+x.v+' '+TESTS[x.k].u+' ('+new Date(x.ts).toLocaleDateString('de-DE')+')'),
  fitness:FC?(()=>{try{return{gewichtKg:FC.kg(),zielKg:FC.goalKg(),zielDatum:FC.goalDate(),schritteHeute:FC.steps(),schrittziel:FC.stepGoal(),kalorienzielHeute:FC.kcalTarget(iso()),schichtHeute:SHIFT[FC.dayKind(iso())]||'unbekannt',woche:WD.map((d,i)=>d+': '+(fcLine(i)||'–'))}}catch(e){return null}})():null,
  strava:'Läuft regelmäßig 5–10 km im Tempo ~6:20/km, wenig Krafttraining, seit August weniger aktiv.',
  einheitenTypen:Object.values(T).map(t=>t.n+' ('+t.l+')'),uebungen:Object.keys(X).map(id=>ex(id).n)}}
const RULES=()=>`Du bist der persönliche KI-Coach in einer Trainings-App für einen Fußball-Torwart (Amateur). Du bist erfahrener Torwart- und Athletiktrainer.
Regeln: Antworte auf Deutsch, per Du, motivierend aber ehrlich, kurz und konkret (meist unter 150 Wörtern). Nutze die Daten unten (Ziel, Plan, Tagesform, letzte Einheiten mit Gewichten, Tests). Empfiehl bevorzugt Übungen und Einheiten, die es in der App gibt, mit Sätzen×Wiederholungen. Er nimmt außerdem ab (Daten unter "fitness": Gewicht, Ziel, Schichtdienst Früh/Spät/Nacht, geplante Läufe). Berücksichtige Schichten, Erholung und Kaloriendefizit. Bei Schmerzen: keine Diagnose, Belastung reduzieren, schmerzfreie Alternativen nennen und bei anhaltenden Beschwerden Arzt oder Physio empfehlen. Formatiere mit kurzen Absätzen, **fett** für Wichtiges und Listen mit "- ".
DATEN DES SPIELERS (JSON):
${JSON.stringify(ctxData())}`;
function md(t){return esc(t).replace(/\*\*(.+?)\*\*/g,'<b>$1</b>').split(/\n{2,}/).map(b=>/^\s*[-•] /m.test(b)?b.replace(/^(?!\s*[-•] )(.+)$/gm,'<p>$1</p>').replace(/((?:^\s*[-•] .*(?:\n|$))+)/gm,m=>'<ul>'+m.trim().split('\n').map(x=>'<li>'+x.replace(/^\s*[-•] /,'')+'</li>').join('')+'</ul>'):'<p>'+b.replace(/\n/g,'<br>')+'</p>').join('')}
function renderCoach(){const m=$('msgs');if(!S.chat.length)m.innerHTML=`<div class="msg a"><p>Hi${S.name?' '+esc(S.name):''}! 👋 Ich bin dein Coach. Ich kenne dein Ziel (<b>${esc((GOALS[S.goal]||{}).n||'noch offen')}</b>), deinen Plan und deine letzten Einheiten.</p><p>Frag mich alles rund um Training, Technik, Regeneration oder Spielvorbereitung.</p></div>`;
 else m.innerHTML=S.chat.map(c=>`<div class="msg ${c.role=='user'?'u':'a'}">${c.role=='user'?esc(c.content):md(c.content)}</div>`).join('')+(S.chat.length?'<button class="ft" style="align-self:center;color:var(--blue)" onclick="if(confirm(\'Chat löschen?\')){S.chat=[];save();renderCoach()}">Chat leeren</button>':'');
 $('qs').innerHTML=QS.map(q=>`<button onclick="ask(this.textContent)">${q}</button>`).join('');
 if(sampleFn===null){$('cbar').style.display='none';m.insertAdjacentHTML('beforeend','<div class="msg a">Der KI-Coach funktioniert, wenn du die App über claude.ai geöffnet hast und dort angemeldet bist.</div>')}
 setTimeout(()=>scrollTo(0,document.body.scrollHeight),30)}
async function ask(q){q=(q||'').trim();if(!q||busy)return;if(!sampleFn){toast('Coach wird noch verbunden …');return}
 busy=true;$('cin').value='';S.chat.push({role:'user',content:q});save();renderCoach();
 const m=$('msgs'),b=document.createElement('div');b.className='msg a think';b.textContent='Coach denkt nach';m.appendChild(b);scrollTo(0,document.body.scrollHeight);
 coachCtl=new AbortController();const hist=S.chat.slice(-12);
 try{const {text}=await sampleFn([{role:'user',content:RULES()},...hist],{cache:false,signal:coachCtl.signal,onText:({text})=>{b.classList.remove('think');b.innerHTML=md(text);scrollTo(0,document.body.scrollHeight)}});
  S.chat.push({role:'assistant',content:text});S.chat=S.chat.slice(-30);save()}
 catch(e){b.classList.remove('think');const c=e&&e.code;
  if(c=='not_granted'||c=='sampling_disabled'){b.textContent='Der Coach braucht deine Erlaubnis, Claude zu nutzen. Öffne die App in claude.ai und erlaube den Zugriff.'}
  else if(c=='rate_limited'){b.textContent='Gerade zu viele Anfragen – versuch es gleich nochmal.'}
  else if(c=='cancelled'){b.innerHTML=md(e.text||'Abgebrochen.')}
  else{b.innerHTML=(e&&e.text?md(e.text)+'<br>':'')+'<i>Verbindung unterbrochen – bitte nochmal fragen.</i>'}
  if(S.chat[S.chat.length-1].role=='user')S.chat.pop();save()}
 busy=false}
$('cform').onsubmit=e=>{e.preventDefault();ask($('cin').value)};
(async()=>{try{const c=window.claude||(EMB?(()=>{try{return window.parent.claude}catch(e){return null}})():null);sampleFn=c&&c.use?await c.use('sample'):null}catch(e){sampleFn=null}if(tab=='coach')renderCoach()})();

renderAll();
{const pi=progInfo();if(pi&&pi.done)setTimeout(()=>showSummary(archiveProgram(true)),500);
 else if(!S.goal&&!S.program&&!(S.programs||[]).length&&!S.log.length)setTimeout(()=>goalSheet(true),400);}
try{if('serviceWorker'in navigator&&location.protocol.startsWith('http'))navigator.serviceWorker.register('sw.js').catch(()=>{})}catch(e){}
