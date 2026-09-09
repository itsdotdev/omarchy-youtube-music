import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source = fs.readFileSync(new URL('../Player.qml', import.meta.url), 'utf8');
function block(marker, offset = 0) {
  const from = source.indexOf(marker, offset);
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
vm.runInNewContext(`(function(code) {${block('onExited: function(code)', source.indexOf('id: mixProc'))}})(code)`, mix);
assert.equal(applied, false);
console.log('PASS: mix/search isolation and stale mix rejection');
