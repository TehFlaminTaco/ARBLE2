import {LuaFactory} from 'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm';

const modules = [
    "advancedpatterns",
    "ARBLE2",
    "dictionary",
    "equalite",
    "list",
    "load",
    "meta",
    "misc",
    "mutate"
]

const factory = new LuaFactory();
const lua = await factory.createEngine();

await Promise.all(modules.map(async c=>{
    const res = await fetch(`./lua/${c}.lua`);
    const body = await res.text();
    await factory.mountFile(`${c}.lua`, body);
}));
let error = '';
let txt = '';
let postedTxt = 0;
let postedError = 0;
let nextPost = 0;
function TryPost(){
    if(+new Date() <= nextPost) return;
    nextPost = (+new Date())+1000;
    if(txt.length > 60_000) txt = txt.substring(0,60_000) + "[Message trimmed past 60kb]";
    if(error.length > 60_000) error = error.substring(0,60_000) + "[Message trimmed past 60kb]";
    if(postedTxt < txt.length){
        console.log(`${postedTxt}: ${txt.substring(postedTxt)}`);
        postMessage({type: 'append', txt: txt.substring(postedTxt)});
        postedTxt = txt.length;
    }
    if(postedError < error.length){
        postMessage({type: 'appendError', txt: error.substring(postedError)});
        postedError = error.length;
    }
}

lua.global.set('write', (...args)=>{
    const str = args.map(c=>`${c}`).join();
    txt += str;
    TryPost();
})
lua.global.set('print', (...args)=>{
    const str = args.map(c=>`${c}`).join('\t')+'\n';
    txt += str;
    TryPost();
})
lua.global.set('writeerror', (...args)=>{
    const str = args.map(c=>`${c}`).join();
    error += str;
    TryPost();
})
lua.global.set('printerror', (...args)=>{
    const str = args.map(c=>`${c}`).join('\t')+'\n';
    error += str;
    TryPost();
})
lua.global.set('showmutated', (txt)=>{
    postMessage({
        type: 'showmutated',
        txt
    })
})

lua.doString(`require('ARBLE2')`)
const showruncode = lua.global.get('showruncode');

onmessage = async (ev)=>{
    const {code, inp} = ev.data;
    lua.global.set("readall", ()=>inp);
    try {
        await showruncode(code);
    }catch(e){
        postedError = error.length;
        postedTxt = txt.length;
        console.error(e);
        postMessage({
            type: 'result',
            error, txt
        })
        return;
    }
    postedError = error.length;
    postedTxt = txt.length;
    postMessage({
        type: 'result',
        error, txt
    })
};

postMessage({
    type: 'awake'
});