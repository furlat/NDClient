import { Application, ImageSource, BufferImageSource, Container, Graphics } from 'pixi.js';
import { createCharacterMaterial, setCharacterControls, setCharacterRegion } from '/src/rendering/character-material.mjs';

const $ = id => document.getElementById(id);
const app = new Application();
await app.init({ preference:'webgl', width:800, height:420, resolution:1, antialias:false,
    background:'#243240', autoStart:false, preserveDrawingBuffer:true });
$('canvas').append(app.canvas);
const [cases, authoring] = await Promise.all([
    fetch('/cases.json').then(r=>r.json()),
    fetch('/authoring/characters/sheet-components.json').then(r=>r.json()),
]);
$('coverage').textContent = `${new Set(cases.map(c=>c.pack+'/'+c.character)).size} characters · ${cases.length.toLocaleString()} sheets`;
const empty = new BufferImageSource({ resource: new Uint8Array(4), width:1, height:1,
    format:'rgba8unorm', alphaMode:'no-premultiply-alpha', scaleMode:'nearest' });
let loaded, selected, meshes=[], bitmaps=[], sources=[], playing=false, elapsed=0, generation=0;
let background = [36,50,64];
const options = (element, values, current) => {
    element.replaceChildren(...values.map(value=>new Option(value.replaceAll('-', ' '), value)));
    if(values.includes(current)) element.value = current;
};
const packs = [...new Set(cases.map(c=>c.pack))];
options($('pack'), packs, 'orcs-and-goblins');
function characters(current) {
    options($('character'), [...new Set(cases.filter(c=>c.pack===$('pack').value).map(c=>c.character))], current);
}
function actions(current) {
    options($('action'), cases.filter(c=>c.pack===$('pack').value && c.character===$('character').value).map(c=>c.action), current);
}
characters('Goblin 08'); actions('Attack 5');

async function source(url) {
    const response=await fetch(url);
    if(!response.ok) throw new Error(`Image unavailable: ${url} (${response.status})`);
    const bitmap=await createImageBitmap(await response.blob(), {premultiplyAlpha:'none', colorSpaceConversion:'none'});
    const texture = new ImageSource({resource:bitmap, alphaMode:'no-premultiply-alpha',
        scaleMode:'nearest', autoGenerateMipmaps:false, addressMode:'clamp-to-edge'});
    return {bitmap,texture};
}
function clearLoaded() {
    for(const mesh of meshes){app.stage.removeChild(mesh);mesh.geometry.destroy();mesh.shader.destroy();mesh.destroy();}
    // Mesh.destroy does not own the shared TextureSources. Release each once.
    for(const texture of sources) texture.destroy();
    for(const bitmap of bitmaps) bitmap.close();
    sources=[];bitmaps=[];meshes=[];
}
function fail(error) { $('error').textContent = error.stack ?? String(error); console.error(error); }
async function select(url) {
    const token=++generation;
    const candidate=cases.find(c=>c.url===url);
    if(!candidate) throw new Error('Unknown sheet: '+url);
    playing=false;$('play').textContent='Play';$('status').textContent='Loading original layers…';$('error').textContent='';
    const row=authoring[url];
    const urls={combined:url,body:row.source_layers.body,shadow:row.source_layers.shadow,
        accent:row.composition.has_accent?row.source_layers.accent:null};
    const pairs=await Promise.all(Object.entries(urls).map(async([role,url])=>[role,url?await source(url):null]));
    if(token!==generation){for(const [,p] of pairs)if(p){p.texture.destroy();p.bitmap.close();}return;}
    clearLoaded();selected=candidate;loaded=Object.fromEntries(pairs.map(([role,p])=>[role,p?.texture??empty]));
    for(const [,p] of pairs)if(p){sources.push(p.texture);bitmaps.push(p.bitmap);}
    for(let i=0;i<2;i++){
        const mesh=createCharacterMaterial({sources:loaded,hasAccent:selected.hasAccent,width:128,height:128});
        meshes.push(mesh);app.stage.addChild(mesh);
    }
    options($('pack'),packs,candidate.pack);characters(candidate.character);actions(candidate.action);
    $('frame').max=selected.frames-1;$('frame').value=0;
    $('rate').textContent=selected.fps?`${selected.fps} FPS · existing authored clip rate`:'Preview at 12 FPS · no gameplay clip rate authored';
    $('fxControls').disabled=!selected.hasAccent;
    $('status').textContent=selected.hasAccent?'Body, shadow and original effect connected.':'No nonempty effect in this sheet. VFX controls have no effect.';
    history.replaceState(null,'','#'+encodeURIComponent(url));
    elapsed=0;draw();
}
function controls() {
    const rgb=id=>[1,3,5].map(n=>parseInt($(id).value.slice(n,n+2),16)/255);
    return {body:+$('body').value,shadow:+$('shadow').value,accent:+$('accent').value,
        bodyHue:+$('bodyHue').value/360,accentHue:+$('accentHue').value/360,
        bodyTint:rgb('tintBody'),accentTint:rgb('tintAccent')};
}
function draw() {
    if(!selected) return;
    const frame=+$('frame').value, direction=+$('facing').value;
    const region=[frame/selected.frames,direction/8,1/selected.frames,1/8];
    for(let i=0;i<2;i++) {
        setCharacterRegion(meshes[i],region);
        setCharacterControls(meshes[i],i?controls():{reference:true});
        const zoom=+$('zoom').value;
        meshes[i].scale.set(zoom);
        meshes[i].position.set(i*400+(400-128*zoom)/2,(420-128*zoom)/2);
    }
    $('frameLabel').textContent=`${frame+1} / ${selected.frames}`;
    app.render();
}
const current=()=>cases.find(c=>c.pack===$('pack').value&&c.character===$('character').value&&c.action===$('action').value).url;
$('pack').onchange=()=>{characters();actions();select(current()).catch(fail);};
$('character').onchange=()=>{actions();select(current()).catch(fail);};
$('action').onchange=()=>select(current()).catch(fail);
for(const input of document.querySelectorAll('aside input, #facing, #zoom')) input.oninput=draw;
$('frame').oninput=()=>{elapsed=+$('frame').value/(selected.fps??12);draw();};
$('background').onchange=()=>{
    background={dark:[36,50,64],light:[220,226,232],green:[77,115,72]}[$('background').value];
    app.renderer.background.color=(background[0]<<16)|(background[1]<<8)|background[2];draw();
};
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'Pause':'Play';};
$('reset').onclick=()=>{for(const id of ['body','shadow','accent'])$(id).value=1;for(const id of ['bodyHue','accentHue'])$(id).value=0;for(const id of ['tintBody','tintAccent'])$(id).value='#ffffff';draw();};
for(const button of document.querySelectorAll('[data-solo]'))button.onclick=()=>{
    for(const id of ['body','shadow','accent'])$(id).value=id===button.dataset.solo?1:0;draw();
};
let last=performance.now();
function tick(now){const dt=(now-last)/1000;last=now;if(playing&&selected){elapsed+=dt;const frame=Math.floor(elapsed*(selected.fps??12))%selected.frames;if(frame!==+$('frame').value){$('frame').value=frame;draw();}}requestAnimationFrame(tick);}
requestAnimationFrame(tick);

// Readback hook invokes the exact same production material with an explicit
// pixel region. Tests compare to independently decoded source pixels, not itself.
window.characterReview={cases,select,authoring,app,get loaded(){return loaded;},get meshes(){return meshes;},get selected(){return selected;},
    async pixels({role='material',frame=0,direction=0,full=false,backdrop=null,...values}={}){
        if(!loaded)throw new Error('Load a sheet first');
        const width=full?selected.width:128,height=full?selected.height:128;
        const region=full?[0,0,1,1]:[frame/selected.frames,direction/8,1/selected.frames,1/8];
        const reference=role!=='material';
        const textures=reference?{...loaded,combined:loaded[role]}:loaded;
        const mesh=createCharacterMaterial({sources:textures,hasAccent:selected.hasAccent,width,height,region});
        setCharacterControls(mesh,{...values,reference});
        const target=new Container();
        if(backdrop)target.addChild(new Graphics().rect(0,0,width,height).fill((backdrop[0]<<16)|(backdrop[1]<<8)|backdrop[2]));
        target.addChild(mesh);
        const pixels=app.renderer.extract.pixels({target,resolution:1,antialias:false});
        mesh.geometry.destroy();mesh.shader.destroy();target.destroy({children:true});
        return {width,height,pixels:Array.from(pixels.pixels)};
    },
    set({frame,direction,...values}){
        if(frame!==undefined)$('frame').value=frame;if(direction!==undefined)$('facing').value=direction;
        for(const [key,value] of Object.entries(values))$(key).value=value;
        draw();
    },
};
const initial=decodeURIComponent(location.hash.slice(1));
await select(cases.some(c=>c.url===initial)?initial:current()).catch(fail);
window.characterReview.ready=true;
