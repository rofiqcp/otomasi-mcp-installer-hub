"use strict";
(()=>{const scope=document.querySelector('[data-service]');if(!scope)return;
const status=document.getElementById('service-status');
fetch(scope.dataset.health,{cache:'no-store',credentials:'omit'}).then(async r=>{
 const j=await r.json();if(!r.ok||!j.ok){status.textContent='Periksa native engine ('+(j.http_status||r.status)+')';status.classList.add('offline');return;}
 status.textContent='Gateway online';status.classList.add('online');
}).catch(()=>{status.textContent='Status belum tersedia';status.classList.add('offline')});
for(const btn of document.querySelectorAll('[data-copy]')){btn.addEventListener('click',async()=>{const target=document.querySelector(btn.dataset.copy);if(!target)return;const value=target.textContent.trim();try{await navigator.clipboard.writeText(value);btn.textContent='Copied ✓';setTimeout(()=>btn.textContent='Copy',1400)}catch{btn.textContent='Select text manually';setTimeout(()=>btn.textContent='Copy',2000)}})}
})();
