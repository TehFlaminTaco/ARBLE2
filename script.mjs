require.config({ paths: { "vs": "https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.53.0/min/vs/" }});

window.MonacoEnvironment = {
    getWorkerUrl: function(workerId, label) {
        return `data:text/javascript;charset=utf-8,${encodeURIComponent(`
            self.MonacoEnvironment = { baseUrl: "https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.53.0/min/" };
            importScripts("https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.53.0/min/vs/base/worker/workerMain.min.js");`
        )}`;
    }
};

const editors = new Map();
function edit(id, body, type = "text", selector = undefined){
    const editorElement = document.querySelector(selector ?? `#${id} .body`);

    var editor = monaco.editor.create(editorElement, {
        value: body,
        language: type,
        automaticLayout: true,
        theme: "arble"
    });

    window.addEventListener("resize", () => editor.layout({
        width: editorElement.offsetWidth,
        height: editorElement.offsetHeight
    }));

    editors.set(id, editor);
    return editor;
}

document.querySelectorAll(".label .tab").forEach(tab => {
    tab.addEventListener("click", () => {
        const panel = tab.closest("[id]");
        panel.querySelectorAll(".label .tab").forEach(t => t.classList.remove("active"));
        panel.querySelectorAll(".body").forEach(b => b.hidden = true);
        tab.classList.add("active");
        panel.querySelector("#" + tab.dataset.target).hidden = false;
    });
});

let worker;
async function RunCode(){
    worker?.terminate();
    let txt = '';
    let err = '';
    editors.get('mutated').setValue('...')
    editors.get('output').setValue('...')
    editors.get('error').setValue('...')
    worker = new Worker(new URL('./worker.mjs', import.meta.url), { type: 'module' });
    worker.addEventListener('message', (event) => {
        switch(event.data.type){
            case 'awake':{
                worker.postMessage({
                    code: editors.get('editor').getValue(),
                    inp: editors.get('input').getValue()
                })
                break;
            }
            case 'showmutated':{
                editors.get('mutated').setValue(event.data.txt);
                break;
            }
            case 'append':{
                txt += event.data.txt;
                editors.get('output').setValue(txt);
                break;
            }
            case 'appendError':{
                err += event.data.txt;
                editors.get('error').setValue(err);
                break;
            }
            case 'result':{

                break;
            }
            default: {
                console.dir(event.data);
            }
        }
    });
}

const compress = async str => {
    const stream = new Blob([str]).stream()
        .pipeThrough(new CompressionStream('deflate-raw'));
    const buf = await new Response(stream).arrayBuffer();
    return btoa(String.fromCharCode(...new Uint8Array(buf)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
};

const decompress = async str => {
    const buf = Uint8Array.from(atob(
        str.replace(/-/g, '+').replace(/_/g, '/')
    ), c => c.charCodeAt(0));
    const stream = new Blob([buf]).stream()
        .pipeThrough(new DecompressionStream('deflate-raw'));
    return new Response(stream).text();
};

require(["vs/editor/editor.main"], async function () {
    monaco.editor.defineTheme("arble", {
        base: "vs-dark",
        inherit: true,
        rules: [],
        colors: {
            "editor.background":           "#13151a",
            "editor.foreground":           "#c8cdd8",
            "editorLineNumber.foreground": "#363b47",
            "editorLineNumber.activeForeground": "#555c6e",
            "editor.lineHighlightBackground": "#1a1d24",
            "editorCursor.foreground":     "#e8a045",
            "editor.selectionBackground":  "#e8a04530",
            "editorIndentGuide.background1": "#252830",
        }
    });

    let code = `"Hello, World!"`;
    const url = new URL(window.location);
    if(url.searchParams.has('c')){
        code = await decompress(url.searchParams.get('c'));
    }else if(url.searchParams.has('u')){
        code = url.searchParams.get('u');
    }
    let input = 'some text input';
    if(url.searchParams.has('b')){
        input = await decompress(url.searchParams.get('b'));
    }else if(url.searchParams.has('a')){
        input = url.searchParams.get('a');
    }

    document.getElementById("byte-count").innerText = `${code.length} bytes`
    edit("editor", code, "lua")
    edit("input", input)
    edit("mutated", "", "lua")
        .updateOptions({readOnly: true})
    edit("output", "", "text", "#output-body")
        .updateOptions({readOnly: true})
    edit("error", "", "text", "#error-body")
        .updateOptions({readOnly: true})

    editors.get('editor').onDidChangeModelContent(async (event)=>{
        const code = editors.get('editor').getValue();
        const input = editors.get('input').getValue();
        document.getElementById("byte-count").innerText = `${code.length} bytes`
        // Check if compressed or decompressed is shorter.
        let c = await compress(code);
        let u = encodeURI(code);
        let ci = await compress(input);
        let ui = encodeURI(input);
        const state = {};
        if(u.length < c.length)
            state.u = code;
        else
            state.c = c;
        if(ui.length < ci.length)
            state.a = input;
        else
            state.b = ci;
        history.replaceState(null, '', '?' + new URLSearchParams(state));
        RunCode();
    })

    RunCode();
});

function flashCopied(btn) {
    const original = btn.textContent;
    btn.textContent = 'Copied!';
    btn.disabled = true;
    setTimeout(() => {
        btn.textContent = original;
        btn.disabled = false;
    }, 1500);
}

document.getElementById('btn-codegolf').addEventListener('click', async ()=>{
    const code = editors.get('editor').getValue();
    const md = `# [ARBLE2](https://github.com/TehFlaminTaco/ARBLE2), ${code.length} bytes
${code.replace(/^/gm, "    ")}

[Try it Online!](${window.location})`
    await navigator.clipboard.writeText(md);
    flashCopied(document.getElementById('btn-codegolf'));
});

document.getElementById('btn-cmc').addEventListener('click', async ()=>{
    const code = editors.get('editor').getValue();
    const md = !code.includes('\n')
        ? `[ARBLE2](https://github.com/TehFlaminTaco/ARBLE2), ${code.length} bytes. [\`${code.replace('`', '``')}\`](${window.location})`
        : `[ARBLE2](https://github.com/TehFlaminTaco/ARBLE2), ${code.length} bytes. [Try it Online!](${window.location})`
    await navigator.clipboard.writeText(md);
    flashCopied(document.getElementById('btn-cmc'));
});