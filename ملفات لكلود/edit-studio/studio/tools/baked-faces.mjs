#!/usr/bin/env node
import i from"node:fs";import n from"node:path";import{fileURLToPath as c}from"node:url";import{normalize as a}from"../public/js/model/schema.js";import{checkProject as p,makeGrab as f,offlineFaceAt as l,refusalText as m}from"../server/faceblock.mjs";import{detectFaces as d}from"../server/facetrack.mjs";import{readJsonFile as h}from"../server/platform.mjs";async function u(e){const s=a(h(n.join(e,"project.json"))),t=f();try{return await p(s,{dir:e,grab:t,detect:d,faceAt:await l(s,e)})}finally{t.done()}}function k(e,s=process.platform){const t=String(e&&e.message||e);return e&&e.code==="noFaceTool"?s==="darwin"?t:`${t}
The check needs mediapipe 0.10.21 for Python (Python 3.12, with opencv-python and numpy). The montage skill's setup installs it; MOHRER_FACE_PYTHON names the Python that has it. No block was checked.`:t}async function $(e){const s=e.find(r=>!r.startsWith("--"));if(!s||!i.existsSync(n.join(s,"project.json")))return process.stderr.write(`usage: node v2/tools/baked-faces.mjs <projectDir> [--json]
`),2;let t;try{t=await u(n.resolve(s))}catch(r){return process.stderr.write(`cannot check: ${k(r)}
`),2}if(e.includes("--json"))process.stdout.write(`${JSON.stringify(t,null,1)}
`);else{for(const o of t.items)process.stdout.write(`${o.baked?"BAKED":o.skip?`skip(${o.skip})`:"ok   "} ${o.id} «${o.label}» ${o.from}-${o.to} s${o.evaluated?` hits ${o.hits}/${o.evaluated}`:""}
`);const r=t.items.filter(o=>o.baked);process.stdout.write(r.length?`${m(r)}
`:`none of the ${t.checked} blocks carries his own face
`)}return t.baked.length?1:0}process.argv[1]&&n.resolve(process.argv[1])===c(import.meta.url)&&$(process.argv.slice(2)).then(e=>{process.exitCode=e});export{u as bakedIn,k as cannotCheck};
