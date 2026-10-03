/// Self-contained JavaScript that Agora injects into an AI website to drive it.
///
/// Design notes:
///  * One IIFE, no external dependencies, evaluated fresh per call. Cost is
///    ~1ms, which is irrelevant next to the 400ms completion poll.
///  * Every lookup is TWO-TIER: plain CSS first (fast path), then
///    shadow-piercing CSS, then fuzzy text match. This is what keeps Agora
///    alive across AI-site redesigns.
///  * Input is set through the native `value` setter because React overrides
///    the plain property; without this, the site simply never sees our text.
///  * Nothing here ever rewrites an agent's output. Extraction returns the
///    DOM's own `innerText` and `outerHTML` untouched. That is the Verbatim
///    guarantee, enforced at the lowest level.
class PageScript {
  PageScript._();

  /// Build a call into the page kernel: `(function agoraKernel(op,A){...})(op, args)`.
  ///
  /// Wrapped in a try/catch that converts any thrown JS error into a plain
  /// `{ok:false, error}` map, so a broken selector on a redesigned site can
  /// never crash the Dart isolate. Soft failures (element simply not found)
  /// come back as `{found:false}` with no exception at all.
  static String call(
    String op, [
    Map<String, dynamic> args = const <String, dynamic>{},
  ]) {
    final String o = _enc(op);
    final String a = _enc(args);
    return '(function(){try{return ($_kernel)($o,$a);}'
        'catch(e){return {ok:false,op:$o,error:String((e&&e.message)||e)};}})()';
  }

  static const String _kernel = r'''
function agoraKernel(op, A) {
  var doc = document;

  // ---------- helpers ----------
  function visible(el) {
    if (!el || el.nodeType !== 1) return false;
    var r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    var s = getComputedStyle(el);
    if (!s) return true;
    if (s.display === 'none' || s.visibility === 'hidden' || s.visibility === 'collapse') return false;
    if (parseFloat(s.opacity || '1') < 0.05) return false;
    return true;
  }

  // Collect shadow roots so we can pierce closed-ish UIs. Cached per call.
  function shadowRoots(root) {
    var roots = [];
    var stack = [root];
    while (stack.length) {
      var node = stack.pop();
      var all;
      try { all = node.querySelectorAll('*'); } catch (e) { all = []; }
      for (var i = 0; i < all.length; i++) {
        if (all[i].shadowRoot) { roots.push(all[i].shadowRoot); stack.push(all[i].shadowRoot); }
      }
    }
    return roots;
  }

  function qsaDeep(sel) {
    var out = [], seen = {};
    function scan(root) {
      var found;
      try { found = root.querySelectorAll(sel); } catch (e) { return; }
      for (var i = 0; i < found.length; i++) {
        if (!seen[found[i]]) { seen[found[i]] = 1; out.push(found[i]); }
      }
    }
    scan(doc);
    var rs = shadowRoots(doc);
    for (var j = 0; j < rs.length; j++) scan(rs[j]);
    return out;
  }

  function labels(el) {
    var parts = [];
    try {
      if (el.getAttribute) {
        ['aria-label','title','placeholder','data-placeholder','alt','name','id','data-testid']
          .forEach(function(a){
            var v = el.getAttribute(a);
            if (v) parts.push(v);
          });
      }
      if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
        if (el.placeholder) parts.push(el.placeholder);
        if (el.getAttribute && el.getAttribute('data-placeholder')) parts.push(el.getAttribute('data-placeholder'));
      }
      if (el.innerText) parts.push(el.innerText);
      if (el.textContent) parts.push(el.textContent);
    } catch (e) {}
    return parts.join(' ').toLowerCase();
  }

  // ---------- the two-tier selector ----------
  var TEXT_TAGS = 'button,[role=button],[role=menuitem],[role=option],[role=tab],textarea,input,[contenteditable],[contenteditable=true],a,label,summary,[data-testid],[data-tooltip]';

  function pickOne(spec) {
    if (!spec) return null;
    var css = spec.css || [], txt = spec.text || [];
    var i;
    for (i = 0; i < css.length; i++) {
      try {
        var el = doc.querySelector(css[i]);
        if (visible(el)) return el;
      } catch (e) {}
    }
    // tier 2: shadow-piercing css
    if (css.length) {
      for (i = 0; i < css.length; i++) {
        var deep;
        try { deep = qsaDeep(css[i]); } catch (e) { deep = []; }
        for (var j = 0; j < deep.length; j++) if (visible(deep[j])) return deep[j];
      }
    }
    // tier 3: fuzzy text
    if (txt.length) {
      var pool = qsaDeep(TEXT_TAGS);
      for (i = 0; i < txt.length; i++) {
        var needle = String(txt[i]).toLowerCase();
        if (!needle) continue;
        for (var k = 0; k < pool.length; k++) {
          var cand = pool[k];
          if (visible(cand) && labels(cand).indexOf(needle) !== -1) return cand;
        }
      }
    }
    return null;
  }

  function pickAll(spec) {
    if (!spec) return [];
    var css = spec.css || [], out = [], seen = {}, i, j;
    for (i = 0; i < css.length; i++) {
      var found;
      try { found = qsaDeep(css[i]); } catch (e) { found = []; }
      for (j = 0; j < found.length; j++) {
        if (!seen[found[j]] && visible(found[j])) { seen[found[j]] = 1; out.push(found[j]); }
      }
    }
    return out;
  }

  function describe(el) {
    if (!el) return null;
    var r = el.getBoundingClientRect();
    return {
      tag: el.tagName ? el.tagName.toLowerCase() : '',
      id: el.id || '',
      cls: (el.className && typeof el.className === 'string') ? el.className.slice(0, 180) : '',
      aria: (el.getAttribute && (el.getAttribute('aria-label') || '')) || '',
      role: (el.getAttribute && (el.getAttribute('role') || '')) || '',
      testid: (el.getAttribute && (el.getAttribute('data-testid') || '')) || '',
      text: (el.innerText || '').slice(0, 120),
      w: Math.round(r.width), h: Math.round(r.height),
      // Does this element actually accept typed text? The adapter healer must
      // never propose a <button> as a replacement composer.
      editable: !!(el.isContentEditable ||
                   el.tagName === 'TEXTAREA' ||
                   (el.tagName === 'INPUT' && !/^(button|submit|checkbox|radio|file|image|range)$/i.test(el.type || ''))),
      type: (el.getAttribute && el.getAttribute('type')) || ''
    };
  }

  // ---------- input writing (React-safe) ----------
  function setNativeValue(el, value) {
    var proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype
              : el.tagName === 'SELECT'  ? window.HTMLSelectElement.prototype
              : window.HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) desc.set.call(el, value);
    else el.value = value;
  }

  function fireInput(el, value) {
    el.dispatchEvent(new InputEvent('input', {
      bubbles: true, cancelable: false,
      inputType: 'insertText', data: value
    }));
    // Some frameworks only listen to change.
    try { el.dispatchEvent(new Event('change', { bubbles: true })); } catch (e) {}
  }

  function writeComposer(el, text) {
    if (!el) return false;
    el.focus();
    var tag = el.tagName;
    if (tag === 'TEXTAREA' || tag === 'INPUT') {
      setNativeValue(el, text);
      fireInput(el, text);
    } else if (el.isContentEditable) {
      // Preserve any child structure the framework expects; clear then insert.
      while (el.firstChild) el.removeChild(el.firstChild);
      var p = doc.createTextNode(text);
      el.appendChild(p);
      fireInput(el, text);
    } else {
      setNativeValue(el, text);
      fireInput(el, text);
    }
    // Give React/Angular a beat to register, then report what it sees.
    return true;
  }

  function pressEnter(el) {
    if (!el) return false;
    el.focus();
    ['keydown','keypress','keyup'].forEach(function(type){
      var ev;
      try {
        ev = new KeyboardEvent(type, {
          key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
          bubbles: true, cancelable: true
        });
      } catch (e) {
        ev = doc.createEvent('Event');
        ev.initEvent(type, true, true);
        ev.keyCode = 13;
      }
      el.dispatchEvent(ev);
    });
    return true;
  }

  function click(el) {
    if (!el) return false;
    el.scrollIntoView({block:'center'});
    ['pointerdown','mousedown','pointerup','mouseup','click'].forEach(function(type){
      try {
        var Ctor = type.indexOf('pointer') === 0 ? window.PointerEvent : window.MouseEvent;
        el.dispatchEvent(new Ctor(type, {bubbles:true, cancelable:true, view:window, button:0}));
      } catch (e) {
        try { el.dispatchEvent(new MouseEvent(type, {bubbles:true, cancelable:true, view:window})); } catch (e2) {}
      }
    });
    return true;
  }

  function composerValue(el) {
    if (!el) return '';
    if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') return el.value || '';
    return el.innerText || el.textContent || '';
  }

  // ---------- extraction ----------
  function lastAssistant(spec) {
    var nodes = pickAll(spec);
    if (!nodes.length) return {found:false, text:'', html:'', streaming:false, index:-1, count:0};
    var last = nodes[nodes.length - 1];
    return {
      found: true,
      // VERBATIM: innerText is the site's own rendering. Not normalised.
      text: last.innerText == null ? '' : last.innerText,
      html: last.outerHTML == null ? '' : last.outerHTML,
      node: describe(last),
      count: nodes.length,
      index: nodes.length - 1
    };
  }

  function isStreaming(specs) {
    var list = specs || [];
    for (var i = 0; i < list.length; i++) {
      if (pickOne(list[i])) return true;
    }
    return false;
  }

  // ---------- ops ----------
  var ops = {
    ping: function () { return {ok:true, url: location.href, title: doc.title}; },

    find: function (a) { var el = pickOne(a.spec); return {found: !!el, el: describe(el)}; },

    exists: function (a) { return {found: !!pickOne(a.spec)}; },

    count: function (a) { return {count: pickAll(a.spec).length}; },

    write: function (a) {
      var el = pickOne(a.spec);
      if (!el) return {ok:false, error:'composer not found'};
      writeComposer(el, a.text);
      return {ok:true, seen: composerValue(el).length, el: describe(el)};
    },

    readComposer: function (a) {
      var el = pickOne(a.spec);
      return {found: !!el, value: composerValue(el), el: describe(el)};
    },

    pressEnter: function (a) {
      var el = pickOne(a.spec) || doc.activeElement || doc.body;
      return {ok: pressEnter(el)};
    },

    click: function (a) {
      var el = pickOne(a.spec);
      if (!el) return {ok:false, error:'button not found'};
      return {ok: click(el), el: describe(el)};
    },

    lastMessage: function (a) { return lastAssistant(a.spec); },

    streaming: function (a) { return {streaming: isStreaming(a.specs)}; },

    navigate: function (a) { location.href = a.url; return {ok:true}; },

    // Calibration Studio + Adapter Healer: dump everything that LOOKS like it
    // could be each role, so a human (or the healer) can pick a selector.
    probe: function (a) {
      var pool = qsaDeep(TEXT_TAGS);
      var out = [];
      for (var i = 0; i < pool.length && out.length < 400; i++) {
        var el = pool[i];
        if (!visible(el)) continue;
        var d = describe(el);
        if (!d) continue;
        d.rectTop = Math.round(el.getBoundingClientRect().top);
        d.shadow = !!el.getRootNode && el.getRootNode() !== doc;
        out.push(d);
      }
      return {url: location.href, title: doc.title, count: out.length, elements: out};
    },

    // Suggest a CSS selector for an element, preferring stable attributes.
    suggest: function (a) {
      var el = pickOne(a.spec);
      if (!el) return {ok:false};
      var cand = [];
      if (el.getAttribute) {
        ['data-testid','data-test','data-qa','aria-label','name','role'].forEach(function(a2){
          var v = el.getAttribute(a2);
          if (v) cand.push(a2 + '="' + v + '"');
        });
      }
      if (el.id) cand.push('#' + el.id);
      if (el.tagName) {
        var base = el.tagName.toLowerCase();
        if (el.className && typeof el.className === 'string') {
          var stable = el.className.split(/\s+/).filter(function(c){
            return c && !/\b(hash|sc|css)-?[a-z0-9]{4,}\b/i.test(c);
          }).slice(0, 2);
          if (stable.length) cand.push(base + '.' + stable.join('.'));
        }
        cand.push(base);
      }
      // Verify each candidate resolves back to this exact element.
      var verified = [];
      for (var i = 0; i < cand.length; i++) {
        try {
          var hit = doc.querySelectorAll(cand[i]);
          if (hit.length === 1 && hit[0] === el) verified.push({selector: cand[i], exact: true});
          else if (hit.length >= 1) verified.push({selector: cand[i], exact: false, matches: hit.length});
        } catch (e) {}
      }
      return {ok:true, el: describe(el), candidates: verified, label: labels(el).slice(0, 80)};
    },

    text: function () {
      var b = doc.body;
      return {text: b ? b.innerText.slice(0, 5000) : '', url: location.href};
    },

    // Diagnostic only: report what each selector in a slot actually finds on
    // this page right now. It reuses the same qsaDeep/visible/labels helpers the
    // real matcher uses, so a green probe means the matcher will find it too.
    probe: function (A) {
      var spec = A.spec || {}, css = spec.css || [], txt = spec.text || [], out = [];
      var i, j;
      function sample(els) {
        if (!els || !els.length) return '';
        return labels(els[0]).replace(/\s+/g, ' ').trim().slice(0, 60);
      }
      for (i = 0; i < css.length; i++) {
        var sel = css[i], found = [], bad = false;
        // qsaDeep swallows a syntax error and returns [], so ask the document
        // directly: "no match" and "not valid CSS" are different calibration bugs.
        try { doc.querySelectorAll(sel); } catch (e) { bad = true; }
        if (!bad) { try { found = qsaDeep(sel); } catch (e) { found = []; } }
        var vis = [];
        for (j = 0; j < found.length; j++) if (visible(found[j])) vis.push(found[j]);
        out.push({selector: sel, kind: 'css', total: found.length, visible: vis.length,
                  sample: sample(vis.length ? vis : found), invalid: bad});
      }
      var pool = qsaDeep(TEXT_TAGS);
      for (i = 0; i < txt.length; i++) {
        var needle = String(txt[i]).toLowerCase(), hits = [], nv = 0;
        for (j = 0; j < pool.length; j++) {
          if (!needle || labels(pool[j]).indexOf(needle) !== -1) {
            hits.push(pool[j]);
            if (visible(pool[j])) nv++;
          }
        }
        out.push({selector: txt[i], kind: 'text', total: hits.length, visible: nv,
                  sample: sample(hits), invalid: false});
      }
      return {ok:true, slot: A.slot || '', hits: out,
              shadowRoots: shadowRoots(doc).length, url: location.href};
    }
  };

  if (!ops[op]) return {ok:false, error:'unknown op: ' + op};
  return ops[op](A || {});
}
''';
}

/// Minimal JSON encoder used by [PageScript.call]. Hand-rolled so the whole
/// page kernel and its argument marshalling live in one dependency-free file.
String _enc(Object? v) {
  if (v == null) return 'null';
  if (v is num || v is bool) return '$v';
  if (v is String) {
    final StringBuffer b = StringBuffer('"');
    for (final int r in v.runes) {
      switch (r) {
        case 0x22:
          b.write(r'\"');
          break;
        case 0x5C:
          b.write(r'\\');
          break;
        case 0x0A:
          b.write(r'\n');
          break;
        case 0x0D:
          b.write(r'\r');
          break;
        case 0x09:
          b.write(r'\t');
          break;
        default:
          if (r < 0x20) {
            b.write('\\u${r.toRadixString(16).padLeft(4, '0')}');
          } else {
            b.writeCharCode(r);
          }
      }
    }
    b.write('"');
    return b.toString();
  }
  if (v is List) return '[${v.map(_enc).join(',')}]';
  if (v is Map) {
    return '{${v.entries.map((MapEntry<Object?, Object?> e) => '${_enc('${e.key}')}:${_enc(e.value)}').join(',')}}';
  }
  return _enc('$v');
}
