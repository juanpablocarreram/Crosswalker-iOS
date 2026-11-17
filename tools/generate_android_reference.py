"""Execute the pinned branch's Kotlin engine, retaining baseline plans plus a broad matrix."""
import json, subprocess, os, itertools
from android_reference import ROOT, COMMIT, BRANCH, prepare, sha
source=prepare(); engine=source/'app/src/main/java/com/example/crosswalker/game/Simulation.kt'
campaign=json.loads((source/'assets/game/files/campaign.json').read_text())
build=ROOT/'.reference-build';build.mkdir(exist_ok=True)
def s(v): return json.dumps(v,ensure_ascii=False)
def f(v): return repr(float(v))+'.toFloat()'
def strings(v): return 'listOf<String>('+','.join(s(x) for x in v)+')'
def ints(v): return 'listOf('+','.join(map(str,v))+')'
def boolean(v): return str(v).lower()
levels=[]
for l in campaign['levels']:
    lanes=','.join('Lane('+','.join(f(a[k]) for k in ['y','speed','offset'])+','+s(a['car'])+','+boolean(a.get('twoWay',False))+','+f(a.get('oncomingOffset',.7))+','+boolean(a.get('blindSpot',False))+')' for a in l['lanes'])
    walkers=','.join('Walker('+','.join(s(w[k]) for k in ['id','name','kind'])+','+f(w['speed'])+','+s(w['sprite'])+')' for w in l['walkers'])
    args=[str(l['id']),str(l['world']),s(l['title']),s(l['lesson']),str(l['budget']),boolean(l['night']),'listOf('+lanes+')','listOf('+walkers+')']
    for k in ['tools','newTools','introLines','guideTools']:
        if k in l: args.append(k+'='+strings(l[k]))
    for k in ['tutorial','trafficYields','rainBrakingLesson']:
        if k in l: args.append(k+'='+boolean(l[k]))
    for k in ['readyMessage','weather']:
        if k in l: args.append(k+'='+s(l[k]))
    for k in ['parCost','blockedCrossing']:
        if k in l: args.append(k+'='+str(l[k]))
    for k in ['accessible','pedestrianCrossings','initialCrossings']:
        if k in l: args.append(k+'='+ints(l[k]))
    if 'sight' in l: args.append('sight=listOf('+','.join(f(x) for x in l['sight'])+')')
    if 'trafficPace' in l: args.append('trafficPace='+f(l['trafficPace']))
    levels.append('Level('+','.join(args)+')')
tools=','.join('Tool('+','.join(s(t[k]) for k in ['id','label','icon'])+','+str(t['cost'])+','+','.join(s(t[k]) for k in ['description','category'])+')' for t in campaign['tools'])
# Original reference inputs remain as an independently stored regression suite.
baseline=ROOT/'CrosswalkerTests/Fixtures/baseline-plans.json'
if not baseline.exists():
    old=json.loads((ROOT/'CrosswalkerTests/Fixtures/trajectories.json').read_text())
    baseline.write_text(json.dumps([{k:t[k] for k in ['name','level','crossings','skills','street']} for t in old],ensure_ascii=False,indent=2)+'\n')
cases=json.loads(baseline.read_text())
for l in campaign['levels']:
    skill_ids=[t['id'] for t in campaign['tools'] if t['category']=='skill' and t['id'] in l['tools']]
    street_ids=[t['id'] for t in campaign['tools'] if t['category']=='street' and t['id'] in l['tools']]
    positions=l.get('initialCrossings') or [1,0,2][:len(l['walkers'])]
    orders=list(itertools.permutations([i for i in range(3) if i!=l.get('blockedCrossing')],len(l['walkers'])))
    for mode in range(26):
        skills={w['id']:[] for w in l['walkers']};street=[];crossings=list(positions)
        if mode>0:
            for w in l['walkers']:
                skills[w['id']]=[x for x in skill_ids if x=='look' or (mode>=2 and ((x=='phone_away' and w['kind']=='phone') or (x=='headphones_off' and w['kind']=='headphones') or (x=='escort' and w['kind']=='impulsive')))]
        if mode in range(3,11): street=[v for i,v in enumerate(street_ids) if (mode-3)&(1<<i)]
        if mode in range(11,20):
            street=street_ids[:]
            for w in l['walkers']: skills[w['id']]=skill_ids[:]
            if orders: crossings=list(orders[(mode-11)%len(orders)])
            if mode==16: street=[x for x in street if x!='speed_zone']
            if mode==17: street=[x for x in street if x!='car_lights']
            if mode==18:
                for v in skills.values():
                    if 'phone_away' in v:v.remove('phone_away')
            if mode==19:
                for v in skills.values():
                    if 'headphones_off' in v:v.remove('headphones_off')
        if mode==20: crossings=[1]*len(crossings)
        if mode==21: crossings[0]=l.get('blockedCrossing',3)
        if mode==22: street=['unavailable_tool']
        if mode==23:
            street=street_ids[:]
            for w in l['walkers']: skills[w['id']]=[x for x in skill_ids if x!='look']
        if mode==24: crossings=[0,1,2][:len(crossings)]
        if mode==25: crossings=[2,1,0][:len(crossings)]
        cases.append(dict(name=f'matrix-{mode}',level=l['id'],crossings=crossings,skills=skills,street=street))
plans=[]
for c in cases:
    l=next(l for l in campaign['levels'] if l['id']==c['level'])
    assignments=','.join(s(w['id'])+' to Assignment('+str(x)+','+strings(c['skills'].get(w['id'],[]))+'.toMutableSet())' for w,x in zip(l['walkers'],c['crossings']))
    plans.append('run('+s(c['name'])+',levels.first { it.id=='+str(c['level'])+' },Plan(mutableMapOf('+assignments+'),'+strings(c['street'])+'.toMutableSet()))')
# JSON functions depend on org.json, but the actual engine above that section is standalone.
(build/'Simulation.kt').write_text(engine.read_text().split('// --- JSON')[0].replace('import org.json.JSONObject\n',''))
harness=r'''import com.example.crosswalker.game.*
import com.example.crosswalker.*
fun json(v:Any?):String = when(v) {
null -> "null"
is String -> "\""+v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r")+"\""
is Map<*,*> -> v.entries.joinToString(",","{","}") { json(it.key.toString())+":"+json(it.value) }
is Iterable<*> -> v.joinToString(",","[","]") { json(it) }
else -> v.toString()
}
fun main() {
val levels=listOf(LEVELS)
val tools=listOf(TOOLS)
val results=mutableListOf<Map<String,Any?>>()
fun run(name:String,l:Level,p:Plan) {
val sim=Simulation(l,p);val samples=mutableListOf<Map<String,Any?>>()
var frame=0
fun sample() { samples.add(linkedMapOf("frame" to frame,"phase" to sim.phase.name.lowercase(),"time" to sim.time,"peopleY" to sim.people.map { it.y },"peopleDone" to sim.people.map { it.done },"cars" to l.lanes.map { sim.carX(it) },"speeds" to l.lanes.map { sim.carSpeed(it) },"braking" to l.lanes.map { sim.isBraking(it) },"oncoming" to l.lanes.filter { it.twoWay }.map { sim.oncomingCarX(it) },"ambushCars" to l.lanes.map { lane -> sim.ambushCarsFor(lane).map { listOf(it.first,it.second) } },"feedback" to sim.feedback,"sight" to l.walkers.map { if ((p.people[it.id]?.crossing ?: 1) in l.sight.indices) sim.sightRange(it.id) else null },"impactSpeed" to sim.impactSpeed)) }
sample()
while(sim.phase==Phase.RUNNING && frame<1802) { sim.tick();frame++;if(frame==1 || frame%10==0 || sim.phase!=Phase.RUNNING) sample() }
results.add(linkedMapOf("name" to name,"level" to l.id,"crossings" to l.walkers.map { p.people.getValue(it.id).crossing },"skills" to p.people.mapValues { it.value.skills.toList() },"street" to p.street.toList(),"cost" to p.cost(tools),"stars" to sim.stars(p.cost(tools)),"reason" to sim.reason,"collapsedWalker" to sim.collapsedWalkerId,"collapsedRole" to sim.collapsedCarRole?.name?.lowercase(),"samples" to samples))
}
PLANS
println(json(results))
val tutorial = (0..(levels.first().introLines.size+2)).flatMap { index -> listOf(false,true).flatMap { look -> listOf(false,true).map { open ->
val step = tutorialStepFor(index,levels.first().introLines.size,look,open)
mapOf("index" to index,"count" to levels.first().introLines.size,"look" to look,"open" to open,"spotlight" to step.spotlightId,"tap" to step.tapId)
} } }
val voices = listOf("ana","tomas","luz","mateo","leo","walker_chair").associateWith { kotlin.math.abs(it.hashCode()) % 6 }
println(json(mapOf("tutorial" to tutorial,"voices" to voices)))
}
'''.replace('LEVELS',','.join(levels)).replace('TOOLS',tools).replace('PLANS','listOf<() -> Unit>(\n'+',\n'.join('{ '+p+' }' for p in plans)+'\n).forEach { it() }')
(build/'Reference.kt').write_text(harness)
env=dict(os.environ,JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home')
compiler='/Applications/Android Studio.app/Contents/plugins/Kotlin/kotlinc/bin/kotlinc'
subprocess.run([compiler,str(build/'Simulation.kt'),str(source/'app/src/main/java/com/example/crosswalker/TutorialStep.kt'),str(build/'Reference.kt'),'-include-runtime','-d',str(build/'reference.jar')],env=env,check=True)
result=subprocess.run([env['JAVA_HOME']+'/bin/java','-jar',str(build/'reference.jar')],check=True,stdout=subprocess.PIPE,text=True)
traces=json.loads(result.stdout.splitlines()[0])
(ROOT/'CrosswalkerTests/Fixtures/presentation.json').write_text(result.stdout.splitlines()[1]+'\n')
(ROOT/'CrosswalkerTests/Fixtures/trajectories.json').write_text(json.dumps(traces,ensure_ascii=False,separators=(',',':'))+'\n')
(ROOT/'Documentation/android-reference.json').write_text(json.dumps({'commit':COMMIT,'branch':BRANCH,'sourceSHA256':sha(engine),'traces':len(traces),'samples':sum(len(t['samples']) for t in traces),'outcomes':{phase:sum(t['samples'][-1]['phase']==phase for t in traces) for phase in ['won','retry','running']}},indent=2)+'\n')
print(f'Recorded {len(traces)} independent Kotlin trajectories from {BRANCH}@{COMMIT}.')
