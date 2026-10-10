/** Real GPU output vs original PNGs. Requires Playwright and Python Pillow/NumPy.
 * PYTHON=/path/to/python PLAYWRIGHT_MODULE=/path/to/playwright/index.js
 * BROWSER_EXECUTABLE=/path/to/chromium node tests/character-material.browser.mjs
 * Start tools/serve_character_review.py first; REVIEW_URL defaults to :8798.
 */
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
const require=createRequire(import.meta.url);
const { chromium }=require(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const python=spawn(process.env.PYTHON ?? 'python3',['tests/character_material_expected.py']);
python.stderr.pipe(process.stderr);
const lines=createInterface({input:python.stdout})[Symbol.asyncIterator]();
const browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_EXECUTABLE,
    args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const errors=[];
let comparisons=0, maximumError=0;
try {
    const page=await browser.newPage({viewport:{width:1250,height:900}});
    page.on('pageerror',e=>errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    await page.goto(process.env.REVIEW_URL ?? 'http://127.0.0.1:8798/');
    await page.waitForFunction(()=>window.characterReview?.ready);
    const cases=await page.evaluate(()=>characterReview.cases);
    assert.equal(cases.length,1368);
    // One effect action (when present) from every owned creature, plus known
    // occlusion-heavy casts and no-accent actions. These are not new rig bindings.
    const byCharacter=new Map();
    for(const c of cases){const k=c.pack+'/'+c.character;const old=byCharacter.get(k);if(!old||(!old.hasAccent&&c.hasAccent))byCharacter.set(k,c);}
    const selected=[...byCharacter.values()];
    for(const suffix of ['Goblin 08/Attack 5.png','Goblin 08/Attack 6.png','Goblin 08/Idle.png','Demon Beast 1/Idle.png']){
        const c=cases.find(c=>c.url.endsWith(suffix));if(!selected.includes(c))selected.push(c);
    }
    for(const [index,c] of selected.entries()) {
        await page.evaluate(url=>characterReview.select(url),c.url);
        const frame=Math.min(c.frames-1, Math.floor(c.frames*.65)),direction=index%8;
        const backdrop=index%2?[220,226,232]:[36,50,64];
        python.stdin.write(JSON.stringify({url:c.url,frame,direction,backdrop})+'\n');
        const line=await lines.next();assert(!line.done,'Source expectation process ended early');
        const expected=JSON.parse(line.value);
        const settings={neutral:{},body:{shadow:0,accent:0},shadow:{body:0,accent:0},
            accent:{body:0,shadow:0},bodyOff:{body:0},effectOff:{accent:0},allOff:{body:0,shadow:0,accent:0}};
        for(const [name,values] of Object.entries(settings)){
            const rendered=await page.evaluate(p=>characterReview.pixels(p),{...values,frame,direction,backdrop});
            const wanted=Buffer.from(expected[name],'base64');
            assert.equal(rendered.pixels.length,wanted.length);
            let max=0;for(let i=0;i<wanted.length;i++)max=Math.max(max,Math.abs(wanted[i]-rendered.pixels[i]));
            assert(max<=1,`${c.character} ${c.action} ${name}: GPU/source max error ${max}`);
            maximumError=Math.max(maximumError,max);comparisons++;
        }
        if(index%10===0)console.log(`${index+1}/${selected.length} characters/actions checked`);
    }
    // Every frame/facing of the formerly failing glow: comparison covers the
    // shader, aligned sampling and entire source sheet, not merely one screenshot.
    for(const suffix of ['Goblin 08/Attack 5.png','Goblin 08/Attack 6.png','Demon Beast 1/Attack 1.png']){
        const c=cases.find(c=>c.url.endsWith(suffix));await page.evaluate(u=>characterReview.select(u),c.url);
        const result=await page.evaluate(async()=>{
            const original=(await characterReview.pixels({role:'combined',full:true})).pixels;
            const neutral=(await characterReview.pixels({full:true})).pixels;
            let difference=0,visible=0;for(let i=0;i<original.length;i+=4)if(original[i+3]){
                visible++;for(let j=0;j<4;j++)difference=Math.max(difference,Math.abs(original[i+j]-neutral[i+j]));}
            return {difference,visible};
        });
        assert(result.visible>0);assert(result.difference<=1,`${suffix} neutral differs: ${result.difference}`);
    }
    // All strengths remain premultiplied; colour controls do not change alpha.
    const effects=cases.find(c=>c.url.endsWith('Goblin 08/Attack 5.png'));
    await page.evaluate(u=>characterReview.select(u),effects.url);
    const colour=await page.evaluate(async()=>{
        const base=(await characterReview.pixels({frame:13,direction:7})).pixels;
        const changed=(await characterReview.pixels({frame:13,direction:7,bodyHue:1/3,accentHue:.5})).pixels;
        let alpha=0,rgb=0;for(let i=0;i<base.length;i++)if(i%4===3)alpha=Math.max(alpha,Math.abs(base[i]-changed[i]));else rgb+=base[i]!==changed[i];
        return{alpha,rgb};
    });assert.equal(colour.alpha,0);assert(colour.rgb>100);
    await page.evaluate(()=>characterReview.set({frame:13,direction:7,bodyHue:120,accentHue:180}));
    await page.screenshot({path:'.runtime/character-components/controls/recoloured.png'});
    await page.click('#play');const first=await page.inputValue('#frame');
    await page.waitForTimeout(220);assert.notEqual(await page.inputValue('#frame'),first);await page.click('#play');
    assert.deepEqual(errors,[]);
    console.log(JSON.stringify({characters:byCharacter.size,sheets:selected.length,endpointComparisons:comparisons,sourceMaxByteError:maximumError,wholeSheetFrames:360,consoleErrors:errors.length}));
} finally {python.stdin.end();python.kill();await browser.close();}
