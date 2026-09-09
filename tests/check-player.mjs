import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = fs.readFileSync(new URL('../Player.qml', import.meta.url), 'utf8');
function block(marker) {
  const from = source.indexOf(marker);
  assert.ok(from >= 0, marker);
  const start = source.indexOf('{', from);
  let depth = 1, end = start + 1;
  while (depth) { if (source[end] === '{') depth++; if (source[end] === '}') depth--; end++; }
  return source.slice(start + 1, end - 1);
}
let played, prefetched;
const ctx = { videoId: 'abcdefghijk', isVideoId: () => true,
  results: {count: 1, get: () => ({videoId: 'abcdefghijk'})},
  searchProc: {running: true, mode: 'search'},
  playAt: i => {played = i;}, prefetchMix: id => {prefetched = id;} };
vm.runInNewContext(`(function(videoId) {${block('function startMix(videoId)')}})(videoId)`, ctx);
assert.equal(played, 0); assert.equal(prefetched, ctx.videoId);
assert.equal(ctx.searchProc.mode, 'search');
let applied = false;
const mix = {code: 0, pending: '', seed: 'abcdefghijk', collected: 'old mix', root: {
  searchMode: true, searching: true, currentVideoId: 'abcdefghijk',
  applyMix: () => {applied = true;}
}};
const mixSection = source.slice(source.indexOf('id: mixProc'));
const marker = mixSection.match(/onExited: function\(code\)/)[0];
// Extract from the specific process because searchProc uses the same signature.
const mixStart = source.indexOf('id: mixProc');
const bodyStart = source.indexOf('onExited: function(code)', mixStart);
const uniqueMarker = source.slice(mixStart, bodyStart) + marker;
vm.runInNewContext(`(function(code) {${block(uniqueMarker)}})(code)`, mix);
assert.equal(applied, false);
console.log('PASS: mix/search isolation and stale mix rejection');
