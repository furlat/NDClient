extends SceneTree
# Published support output and revision-loss recovery, not a world rules cache.
const Overlay=preload("res://presentation/ground_overlay.gd")
const Placement=preload("res://placement.gd")
const Profile=preload("res://frame_profile.gd")
var checks=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("GROUND_SUPPORT_FAIL ",label)
func _initialize()->void:run.call_deferred()
func proof(base:int,revision:int,keys:Dictionary={},scope:Array=[1,[]],full:bool=false)->Dictionary:
    return {"revision":revision,"scope":scope,"changes":{"base_revision":base,"revision":revision,"tiles":keys,"full":full}}
func output(overlay)->Dictionary:
    var cells={}
    for key in overlay.cells:cells[key]=overlay.cells[key].placement
    var routes={}
    for key in overlay.routes:routes[key]=overlay.routes[key].placement
    var background={}
    for position in overlay.background_positions:background[position]=true
    # Batched mark IDs contain each material's native instance ID. Compare its
    # painter rank here; native pixel checks cover the material draw itself.
    return {"support":overlay.support_positions,"raised":overlay.raised_supports,"background":background,"cells":cells,"routes":routes,"ordered":overlay.ordered.map(func(entry):return entry.order_key)}
func compare(overlay,oracle,owner:Node,tiles:Dictionary,revision:int,ledger:Dictionary,label:String)->void:
    overlay.sync(owner,tiles,revision,true,0,true,ledger)
    oracle.sync(owner,tiles,[revision,ledger.scope],true,0,true)
    check(output(overlay)==output(oracle),label+": complete support/route/cell/painter output equals full snapshot")
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(64,64)
    var owner=Node3D.new();root.add_child(owner)
    var tiles={}
    for x in range(37):
        for y in range(34):tiles["%d,%d"%[x,y]]={"position":[x,y],"elevation_steps":0}
    tiles["37,0"]={"position":[37,0],"elevation_steps":0}
    var overlay=Overlay.new();var oracle=Overlay.new()
    var marks={"0,0":{"colour":Color(.5,.8,.7,.5),"width":2.0,"fill_colour":Color(.5,.8,.7,.2)},"1,0":{"colour":Color(.5,.8,.7,.5),"width":2.0,"fill_colour":Color(.5,.8,.7,.2)}}
    overlay.set_preview(marks,[[0,0],[1,0]]);oracle.set_preview(marks,[[0,0],[1,0]])
    compare(overlay,oracle,owner,tiles,0,proof(-1,0,{},[1,[]],true),"Initial snapshot")
    check(overlay.support_checked_tiles==1259,"Initial unproven snapshot checks all disclosed supports")
    var keys={}
    for x in range(18):keys["%d,0"%x]=true;tiles["%d,0"%x].residue={"authored_test_value":x};tiles["%d,0"%x].light=x
    var order=overlay.ordered;var writes=overlay.transform_writes
    compare(overlay,oracle,owner,tiles,1,proof(0,1,keys),"18 residue/light rows")
    check(overlay.support_checked_tiles==18,"Proven residue/light update checks exactly18 rows rather than1259")
    check(is_same(order,overlay.ordered) and overlay.transform_writes==writes and not overlay.changed,"Nongeometric commits preserve native transforms and painter owner")
    check(overlay.mark_update_us==0,"Nongeometric commits skip complete mark regroup")
    compare(overlay,oracle,owner,tiles,1,proof(0,1,keys),"Repeated render")
    check(overlay.support_checked_tiles==0,"Repeated render performs no support scan")
    tiles["0,0"].elevation_steps=2
    compare(overlay,oracle,owner,tiles,2,proof(1,2,{"0,0":true}),"Sparse elevation")
    check(overlay.support_checked_tiles==1 and overlay.raised_supports.has("0,0") and overlay.support_contact_updates==1,"Changed elevation updates exactly one actual contact")
    tiles["3,0"].elevation_steps=3
    compare(overlay,oracle,owner,tiles,4,proof(3,4,{}),"Missed revision")
    check(overlay.support_checked_tiles==1259 and overlay.raised_supports.has("3,0"),"Missed base cannot conceal an unlisted elevation change")
    tiles["4,0"].position=[4,1]
    compare(overlay,oracle,owner,tiles,5,proof(4,5,{},[1,[]],true),"Explicit full snapshot")
    check(overlay.support_checked_tiles==1259,"Explicit full flag retains full fallback")
    tiles=tiles.duplicate(true);tiles["5,0"].elevation_steps=4
    compare(overlay,oracle,owner,tiles,6,proof(5,6,{}),"Replaced snapshot owner")
    check(overlay.support_checked_tiles==1259,"New owner cannot borrow prior sparse ownership")
    tiles["6,0"].elevation_steps=5
    compare(overlay,oracle,owner,tiles,6,proof(6,6,{},[2,[]]),"Seek/epoch replacement with same revision")
    check(overlay.support_checked_tiles==1259,"Epoch change invalidates sparse proof even at same revision")
    var canonical=tiles
    var staged=tiles.duplicate();staged["38,0"]={"position":[38,0],"elevation_steps":6}
    compare(overlay,oracle,owner,staged,7,proof(6,6,{},[2,["operation",["38,0"]]]),"Admitted staged support")
    check(overlay.support_positions.has("38,0") and overlay.support_checked_tiles==1260,"Staged owner/scope takes full disclosed snapshot")
    compare(overlay,oracle,owner,canonical,8,proof(6,6,{},[2,[]]),"Departed staged support")
    check(not overlay.support_positions.has("38,0") and overlay.support_checked_tiles==1259,"Stage retirement removes its support without canonical commit")
    canonical.erase("0,0")
    compare(overlay,oracle,owner,canonical,9,proof(6,7,{"0,0":true},[2,[]]),"Sparse support removal")
    check(overlay.support_checked_tiles==1 and not overlay.support_positions.has("0,0"),"Sparse removal retires cached support")
    check(overlay.support_contact_updates==0,"Support removal never recomputes unchanged contacts")
    canonical["38,0"]={"position":[38,0],"elevation_steps":0}
    canonical["39,0"]={"position":[39,0],"elevation_steps":0}
    compare(overlay,oracle,owner,canonical,10,proof(7,8,{"38,0":true,"39,0":true},[2,[]]),"Two first-disclosed supports")
    check(overlay.support_contact_updates==2 and overlay.support_checked_tiles==2,"Two new supports calculate exactly two contacts")
    canonical["3,0"].elevation_steps=0
    compare(overlay,oracle,owner,canonical,11,proof(8,9,{"3,0":true},[2,[]]),"Raised to background")
    check(overlay.support_contact_updates==1 and not overlay.raised_supports.has("3,0"),"Raised-to-zero updates only its contact and background membership")
    var before_path="res://.runtime/ground-overlay-before-support-ledger.gd"
    var samples=[];var prior=[];var checks_per_update=0
    var insert_support=[];var insert_marks=[];var insert_total=[];var insert_before=[]
    if FileAccess.file_exists(before_path):
        var previous=load(before_path).new()
        previous.sync(owner,canonical,12,true,0,true)
        overlay.sync(owner,canonical,12,true,0,true,proof(9,10,{},[2,[]],true))
        for i in range(100):
            var began=Time.get_ticks_usec();previous.sync(owner,canonical,13+i,true,0,true);prior.append((Time.get_ticks_usec()-began)/1000.0)
            began=Time.get_ticks_usec();overlay.sync(owner,canonical,13+i,true,0,true,proof(10+i,11+i,keys,[2,[]]));samples.append((Time.get_ticks_usec()-began)/1000.0)
            checks_per_update=overlay.support_checked_tiles
        for i in range(20):
            var changed={"40,0":true,"41,0":true}
            for x in [40,41]:
                if i%2==0:canonical["%d,0"%x]={"position":[x,0],"elevation_steps":0}
                else:canonical.erase("%d,0"%x)
            var began=Time.get_ticks_usec();previous.sync(owner,canonical,200+i,true,0,true);insert_before.append((Time.get_ticks_usec()-began)/1000.0)
            began=Time.get_ticks_usec();overlay.sync(owner,canonical,200+i,true,0,true,proof(110+i,111+i,changed,[2,[]]));insert_total.append((Time.get_ticks_usec()-began)/1000.0)
            insert_support.append(overlay.support_check_us/1000.0);insert_marks.append(overlay.mark_update_us/1000.0)
            check(overlay.support_contact_updates==(2 if i%2==0 else 0),"Repeated two-support insertion/removal only computes new contacts")
        previous.close()
        check(checks_per_update==18,"Repeated canonical updates retain18-row proof")
    var report={"checks":checks,"failures":failures,"support_rows":1259,"changed_rows":18,"sync_ms":Profile.distribution(samples),"before_sync_ms":Profile.distribution(prior),"two_support_changes":{"support_check_ms":Profile.distribution(insert_support),"mark_update_ms":Profile.distribution(insert_marks),"sync_ms":Profile.distribution(insert_total),"before_sync_ms":Profile.distribution(insert_before)},"scope":"Isolated CPU support synchronization with unchanged preview; not live FPS"}
    overlay.close();oracle.close();owner.free()
    FileAccess.open("res://.runtime/ground-overlay-support-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("GROUND_OVERLAY_SUPPORT_CHECKS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
