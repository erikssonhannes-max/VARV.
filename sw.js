/* VARV. – offlineläge: sidan och ikonerna sparas så att appen fungerar utan nät. */
const CACHE="varv-v50";
const FILES=["./","index.html","manifest.webmanifest","icons/icon.svg","icons/varv-180.png","icons/varv-192.png","icons/varv-512.png","icons/varv-32.png","supabase-config.js","vendor/supabase.js","data/exercises.json"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(n=>n!==CACHE).map(n=>caches.delete(n)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{
  const r=e.request;if(r.method!=="GET"||new URL(r.url).origin!==location.origin)return;
  // nätet först för sidan så att uppdateringar syns direkt, cache när nätet saknas
  e.respondWith(fetch(r).then(res=>{const copy=res.clone();caches.open(CACHE).then(c=>c.put(r,copy));return res}).catch(()=>caches.match(r).then(m=>m||caches.match("index.html"))));
});

/* Notiser */
self.addEventListener("push",e=>{
  let d={};try{d=e.data?e.data.json():{}}catch(x){d={title:"VARV.",body:e.data?e.data.text():""}}
  e.waitUntil(Promise.all([self.registration.showNotification(d.title||"VARV.",{body:d.body||"",icon:"icons/varv-192.png",badge:"icons/varv-192.png",tag:d.tag||undefined,data:{url:d.url||"./"}}),
    clients.matchAll({type:"window",includeUncontrolled:true}).then(ws=>ws.forEach(w=>w.postMessage({type:"push"})))]));
});
self.addEventListener("notificationclick",e=>{
  e.notification.close();const url=new URL((e.notification.data&&e.notification.data.url)||"./",self.registration.scope).href;
  e.waitUntil(clients.matchAll({type:"window",includeUncontrolled:true}).then(ws=>{for(const w of ws){if("focus" in w){w.navigate(url).catch(()=>{});return w.focus()}}return clients.openWindow(url)}));
});
