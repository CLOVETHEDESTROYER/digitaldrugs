/* Native and browser preview share the unmodified, offline Butterchurn engine. */
'use strict';
(() => {
  const $ = id => document.getElementById(id);
  const native = Boolean(window.webkit?.messageHandlers?.visualLab);
  if (native) document.body.classList.add('native');
  const presets = window.ZenWavePresets;
  let canvas = $('visual');
  let visualizer, index = 6, currentTime = 0, lastCycle = 0, generation = -1;
  let audioContext, source, analyser, splitter, analyserL, analyserR;
  let running = false, pausedOffset = 0, startedAt = 0, buffer, raf;
  const silence = () => new Uint8Array(1024).fill(128);
  let levels = {timeByteArray: silence(), timeByteArrayL: silence(), timeByteArrayR: silence()};
  const notify = (type, message) => {
    $('status').textContent = message;
    window.webkit?.messageHandlers?.visualLab?.postMessage({type, message});
  };
  const resize = () => {
    const box = $('visual').getBoundingClientRect();
    const limit = Number($('quality').value), scale = Math.min(limit / Math.max(1,box.height), 2);
    const w = Math.max(64,Math.round(box.width*scale)), h = Math.max(64,Math.round(box.height*scale));
    canvas.width=w;canvas.height=h; visualizer?.setRendererSize(w,h);
  };
  function loadPreset(next, blend = Number($('blend').value)) {
    index = (next+presets.length)%presets.length;
    visualizer.loadPreset(presets[index].preset,blend);
    $('preset').value=String(index);$('name').textContent=presets[index].title;
    $('credit').textContent=presets[index].authorPreset;
    lastCycle=currentTime;
    window.webkit?.messageHandlers?.visualLab?.postMessage({type:'selection',metalStyle:String(presets[index].metalStyle??-1)});
  }
  function reset() {
    // Recreate feedback state when restarting/seeking or replacing audio.
    // Release all feedback textures/programs when resetting the engine.
    if(visualizer){const old=canvas;const gl=old.getContext('webgl2');old.replaceWith(canvas=old.cloneNode());visualizer=null;gl?.getExtension('WEBGL_lose_context')?.loseContext();}
    const gl=canvas.getContext('webgl2',{alpha:false,antialias:false});
    if(!gl)throw new Error('WebGL 2 is unavailable on this computer. Metal visuals remain available.');
    canvas.addEventListener('webglcontextlost',event=>{if(event.target!==canvas)return;event.preventDefault();stopBrowser();notify('error','The GPU preview was interrupted. Close and reopen Visual Lab, or try Light quality.');});
    visualizer=butterchurn.default.createVisualizer(null,canvas,{width:canvas.width||640,height:canvas.height||640,meshWidth:32,meshHeight:24,pixelRatio:1,textureRatio:1});
    resize();loadPreset(index,0);currentTime=0;lastCycle=0;
  }
  function draw(dt, nextLevels) {
    if(!visualizer)return;
    currentTime+=dt;
    if($('cycle').checked && currentTime-lastCycle>=45){const visible=visibleIndices();loadPreset(visible[(visible.indexOf(index)+1)%visible.length]);}
    visualizer.render({elapsedTime:Math.max(.001,Math.min(.1,dt))*Number($('speed').value),audioLevels:nextLevels});
    $('empty').hidden=true;
  }
  window.ZenWaveLab={
    frame(packet){
      try {
        if(generation!==packet.generation || packet.time<currentTime-.2){reset();generation=packet.generation;currentTime=packet.time;}
        const next={timeByteArray:Uint8Array.from(packet.mono),timeByteArrayL:Uint8Array.from(packet.left),timeByteArrayR:Uint8Array.from(packet.right)};
        draw(packet.delta,next);currentTime=packet.time;
      }catch(error){notify('error',error.message);throw error;}
    },
    reset(){reset();generation=-1;draw(1/30,{timeByteArray:silence(),timeByteArrayL:silence(),timeByteArrayR:silence()});},
    info(){return {ready:Boolean(visualizer),preset:presets[index].authorPreset,time:currentTime,width:canvas.width,height:canvas.height,count:presets.length};}
  };
  function visibleIndices(){return presets.map((p,i)=>i).filter(i=>$('collection').value==='all'||(presets[i].collection||'classic')===$('collection').value);}
  function fillChoices(){ $('preset').replaceChildren();visibleIndices().forEach(i=>$('preset').add(new Option(presets[i].title,String(i)))); }
  fillChoices();
  $('collection').onchange=()=>{fillChoices();loadPreset(visibleIndices()[0]);notify('ready','Collection ready · press Play to compare');};
  $('preset').onchange=()=>{try{loadPreset(Number($('preset').value));if(!native&&!running)draw(1/30,levels);}catch(e){notify('error',e.message);}};
  $('quality').onchange=resize;
  new ResizeObserver(resize).observe(canvas.parentElement);
  async function startBrowser(nextBuffer) {
    audioContext ||= new AudioContext({sampleRate:44100}); await audioContext.resume();
    stopBrowser();
    if(nextBuffer){buffer=nextBuffer;pausedOffset=0;}
    if(!buffer)return;
    source=audioContext.createBufferSource();source.buffer=buffer;source.loop=true;
    analyser=audioContext.createAnalyser();analyser.fftSize=1024;
    analyserL=audioContext.createAnalyser();analyserR=audioContext.createAnalyser();analyserL.fftSize=analyserR.fftSize=1024;
    splitter=audioContext.createChannelSplitter(2);
    source.connect(analyser);source.connect(splitter);splitter.connect(analyserL,0);splitter.connect(analyserR,buffer.numberOfChannels>1?1:0);
    source.connect(audioContext.destination);source.start(0,pausedOffset%buffer.duration);startedAt=audioContext.currentTime;
    running=true;$('pause').disabled=false;$('pause').textContent='Pause';
    let previous=performance.now();
    const tick=now=>{if(!running)return;const dt=(now-previous)/1000;if(dt>=1/30){
      analyser.getByteTimeDomainData(levels.timeByteArray);analyserL.getByteTimeDomainData(levels.timeByteArrayL);analyserR.getByteTimeDomainData(levels.timeByteArrayR);
      draw(dt,levels);previous=now;}raf=requestAnimationFrame(tick);};
    raf=requestAnimationFrame(tick);notify('playing','Background audio drives the visual');
  }
  function stopBrowser(){if(running)pausedOffset+=audioContext.currentTime-startedAt;running=false;cancelAnimationFrame(raf);try{source?.stop();}catch(_){}source?.disconnect();splitter?.disconnect();}
  $('demo').onclick=async()=>{try{
    audioContext ||= new AudioContext({sampleRate:44100});
    const rate=audioContext.sampleRate,demo=audioContext.createBuffer(2,rate*30,rate);
    // Quiet original ambient fixture: filtered noise + a stereo theta carrier.
    for(let c=0;c<2;c++){let low=0;const data=demo.getChannelData(c);for(let i=0;i<data.length;i++){const t=i/rate;low=.985*low+.015*(Math.random()*2-1);data[i]=low*.65+Math.sin(2*Math.PI*(c?206:200)*t)*.055*(.7+.3*Math.sin(2*Math.PI*t/8));}}
    reset();await startBrowser(demo);
  }catch(e){notify('error',e.message);}};
  $('audioFile').onchange=async()=>{try{const file=$('audioFile').files[0];if(!file)return;audioContext ||=new AudioContext({sampleRate:44100});const decoded=await audioContext.decodeAudioData(await file.arrayBuffer());reset();await startBrowser(decoded);}catch(e){notify('error',e.message);}};
  $('pause').onclick=async()=>{if(running){stopBrowser();$('pause').textContent='Resume';notify('paused','Paused');}else await startBrowser();};
  window.addEventListener('pagehide',stopBrowser);
  try{reset();draw(1/30,levels);notify('ready',native?'Ready · prepare audio, then press Play':'Ready · play ambient demo or choose a background track');}
  catch(e){$('empty').textContent=e.message;notify('error',e.message);}
})();
