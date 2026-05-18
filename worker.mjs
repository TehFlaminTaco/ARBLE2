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
lua.global.set('write', (...args)=>{
    const str = args.map(c=>`${c}`).join();
    txt += str;
    postMessage({type: 'append', txt: str})
})
lua.global.set('print', (...args)=>{
    const str = args.map(c=>`${c}`).join('\t')+'\n';
    txt += str;
    postMessage({type: 'append', txt: str})
})
lua.global.set('writeerror', (...args)=>{
    const str = args.map(c=>`${c}`).join();
    error += str;
    postMessage({type: 'appendError', txt: str})
})
lua.global.set('printerror', (...args)=>{
    const str = args.map(c=>`${c}`).join('\t')+'\n';
    error += str;
    postMessage({type: 'appendError', txt: str})
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
        console.error(e);
        postMessage({
            type: 'result',
            error, txt
        })
    }
    postMessage({
        type: 'result',
        error, txt
    })
};

postMessage({
    type: 'awake'
});