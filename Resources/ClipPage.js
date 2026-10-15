// SPDX-License-Identifier: GPL-3.0-or-later
// Detached static HTML, not Markdown. No credential/cookie/storage reads.
var ExtensionPreprocessingJS = {
  run: function (args) {
    var resources = [], warnings = 0, formulaCount = 0;
    var properties = ['color', 'background-color', 'font-family', 'font-size', 'font-weight', 'font-style',
      'line-height', 'text-align', 'text-decoration', 'white-space', 'vertical-align',
      'margin-top', 'margin-bottom', 'padding', 'border-color', 'border-width', 'border-style', 'border-collapse', 'list-style-type',
      'overflow-wrap', 'word-break', 'tab-size', 'overflow-x'];
    var formulaRoots = '.mwe-math-element,.katex-display,.MathJax_Display,.MathJax_SVG_Display,mjx-container,.katex,.MathJax,.MathJax_SVG,math';
    var htmlTags = new Set(('p div span article section main aside header footer h1 h2 h3 h4 h5 h6 a img br hr wbr strong b em i u s small sub sup pre code blockquote ul ol li dl dt dd table thead tbody tfoot tr td th caption colgroup col figure figcaption details summary').split(' '));
    var mathTags = new Set(('math mi mn mo mrow mfrac msqrt mroot msub msup msubsup mtext mover munder munderover mtable mtr mtd semantics annotation mstyle mpadded mspace menclose mfenced mmultiscripts mprescripts none maligngroup malignmark').split(' '));
    // Prefer an explicit article container, never the first paragraph/article of
    // a multi-post page. The source document and explicit user selection stay intact.
    function contentRoot() {
      var wiki = document.querySelector('#mw-content-text .mw-parser-output')
        || document.querySelector('#mw-content-text')
        || (document.body && document.body.matches('.mw-parser-output') ? document.body : null);
      if (wiki && (wiki.textContent.trim() || wiki.querySelector('img,math'))) return {node: wiki, wiki: true};
      // esoTalk (including Chaoli): keep the loaded conversation, not just its
      // first post, but exclude the surrounding page shell and scrubber.
      var forum = document.querySelector('#conversation');
      if (forum && forum.querySelector('#conversationTitle') && forum.querySelector('#conversationPosts.postList .post .postBody')) {
        return {node: forum, wiki: false, forum: true};
      }
      var mains = Array.from(document.querySelectorAll('main,[role="main"]')).filter(function (item) {
        return !item.parentElement.closest('main,[role="main"]') && (item.textContent.trim() || item.querySelector('img,math'));
      });
      return {node: mains.length === 1 ? mains[0] : document.body, wiki: false};
    }
    function inlineStyle(target, original) {
      if (!original || !original.isConnected || mathTags.has(target.localName)) return;
      var computed = window.getComputedStyle(original), result = [];
      properties.forEach(function (name) {
        var value = computed.getPropertyValue(name);
        if (value && value.length <= 160 && !/url\s*\(|expression\s*\(|[{}<>\\]/i.test(value)) result.push(name + ':' + value);
      });
      if (target.localName === 'img') result.push('max-width:100%;height:auto');
      target.setAttribute('style', result.join(';'));
    }
    function normalizeMath(root, original) {
      var math = root.localName === 'math' ? root : root.querySelector('math');
      if (!math && original && window.MathJax && window.MathJax.Hub) {
        try {
          var jax = window.MathJax.Hub.getJaxFor(original);
          if (jax && jax.root && typeof jax.root.toMathML === 'function') {
            var parsed = new DOMParser().parseFromString(jax.root.toMathML(), 'application/xml');
            if (parsed.documentElement.localName === 'math') math = parsed.documentElement;
          }
        } catch (_) { /* Never load extra page scripts. */ }
      }
      if (!math) return false;
      var visible = math.cloneNode(true);
      [visible].concat(Array.from(visible.querySelectorAll('*'))).forEach(function (item) {
        item.removeAttribute('style'); item.removeAttribute('hidden'); item.removeAttribute('aria-hidden');
      });
      var display = root.classList.contains('MathJax_Display') || root.classList.contains('MathJax_SVG_Display') || root.classList.contains('katex-display')
        || root.getAttribute('display') === 'true' || visible.getAttribute('display') === 'block';
      visible.setAttribute('display', display ? 'block' : 'inline');
      var wrapper = document.createElement(display ? 'div' : 'span');
      wrapper.setAttribute('class', 'wiz-clip-formula'); wrapper.appendChild(visible);
      root.replaceWith(wrapper); formulaCount++; return true;
    }
    function selectedFragment(selection) {
      var fragment = document.createElement('div'), sources = new WeakMap(), visited = 0;
      function copyTree(original) {
        if (++visited > 100000) throw new Error('Selection too complex');
        var copy = original.cloneNode(false); sources.set(copy, original);
        Array.from(original.childNodes).forEach(function (child) { copy.appendChild(copyTree(child)); });
        return copy;
      }
      function select(original, range) {
        if (++visited > 100000) throw new Error('Selection too complex');
        if (!range.intersectsNode(original)) return null;
        if (original.nodeType === Node.TEXT_NODE) {
          var start = range.startContainer === original ? range.startOffset : 0;
          var end = range.endContainer === original ? range.endOffset : original.length;
          return end > start ? document.createTextNode(original.data.slice(start, end)) : null;
        }
        if (original.nodeType !== Node.ELEMENT_NODE) return null;
        // A formula is atomic: selecting its visible numerator must not lose
        // a denominator or the hidden accessibility MathML beside the glyphs.
        if (original.matches(formulaRoots)) return copyTree(original);
        var copy = original.cloneNode(false); sources.set(copy, original);
        Array.from(original.childNodes).forEach(function (child) {
          var chosen = select(child, range); if (chosen) copy.appendChild(chosen);
        });
        return copy.childNodes.length || original.matches('img,br,hr') ? copy : null;
      }
      if (selection) for (var i = 0; i < selection.rangeCount; i++) {
        var range = selection.getRangeAt(i); if (range.collapsed) continue;
        var root = range.commonAncestorContainer;
        if (root.nodeType !== Node.ELEMENT_NODE) root = root.parentElement || document.body;
        var formula = root.closest(formulaRoots);
        if (formula) {
          var parentFormula;
          while (formula.parentElement && (parentFormula = formula.parentElement.closest(formulaRoots))) formula = parentFormula;
          root = formula;
        } else root = root.closest('pre') || root.closest('code') || root;
        var chosen = select(root, range); if (chosen) fragment.appendChild(chosen);
      }
      return {node: fragment, sources: sources};
    }
    function snapshot(node, articleMode, sourceMap) {
      var copy = node.cloneNode(true), originals = Array.from(node.querySelectorAll('*')),
        clones = Array.from(copy.querySelectorAll('*')), originalNodes = new WeakMap(), embedded = 0;
      if (clones.length > 100000) throw new Error('Page too complex');
      clones.forEach(function (item, i) {
        var original = sourceMap ? sourceMap.get(originals[i]) : originals[i];
        originalNodes.set(item, original); inlineStyle(item, original);
      });
      inlineStyle(copy, node.isConnected ? node : document.body);
      if (articleMode) {
        // Computed padding/margins belong to the website's surrounding layout,
        // not the standalone note. Do not preserve a sidebar-width offset.
        copy.style.margin = '0'; copy.style.padding = '0'; copy.style.borderWidth = '0';
      }
      if (articleMode === 'wiki') {
        copy.querySelectorAll('.mw-editsection,.navbox,.navbox-styles,.vertical-navbox,.ambox .mbox-image,.mw-jump-link,.mw-indicators,.vector-header-container,.vector-column-start,.vector-column-end,#mw-panel-toc,#footer,.mw-footer').forEach(function (item) { item.remove(); });
        // References, notes, infoboxes, tables, figures and section anchors are
        // article content; do not blanket-delete aside/header/footer or lists.
      }
      if (articleMode === 'forum') {
        copy.querySelectorAll('.scrubberColumn,#conversationReply,.timeMarker').forEach(function (item) { item.remove(); });
        var header = copy.querySelector('#conversationHeader');
        if (header) Array.from(header.children).forEach(function (item) { if (item.id !== 'conversationTitle') item.remove(); });
        copy.querySelectorAll('#conversationPosts .post').forEach(function (post) {
          // Only remove forum-owned direct children. Never strip a quoted
          // header/footer, list, figure or signature-looking class in the body.
          Array.from(post.children).forEach(function (item) { if (item.classList.contains('avatar')) item.remove(); });
          var content = Array.from(post.children).find(function (item) { return item.classList.contains('postContent'); });
          if (!content) return;
          Array.from(content.children).forEach(function (item) { if (item.classList.contains('postFooter')) item.remove(); });
          var heading = content.querySelector('.postHeader');
          if (heading) {
            heading.querySelectorAll('.controls,.group').forEach(function (item) { item.remove(); });
            heading.querySelectorAll('h3').forEach(function (item) { item.style.fontSize = '14px'; item.style.margin = '0 0 4px'; });
          }
        });
        copy.querySelectorAll('#conversationHeader,#conversationBody,#conversationPosts,#conversationPosts > li,#conversationPosts .post,#conversationPosts .postContent,#conversationPosts .postHeader,#conversationPosts .postHeader .info,#conversationPosts .postBody').forEach(function (item) {
          item.style.margin = '0'; item.style.padding = '0'; item.style.borderWidth = '0';
        });
        var posts = copy.querySelector('#conversationPosts');
        if (posts) posts.style.listStyleType = 'none';
        copy.querySelectorAll('#conversationPosts > li').forEach(function (item) {
          item.style.listStyleType = 'none'; item.style.marginTop = '16px'; item.style.padding = '0 0 16px';
          item.style.borderWidth = '0 0 1px'; item.style.borderStyle = 'solid'; item.style.borderColor = '#d7dbdf';
        });
      }
      // A detached selection is not a page canvas. Importing the body colour
      // here paints the selected fragment as a large highlighted rectangle.
      var backdrop = articleMode === 'selection' ? null : document.body, opaqueBackdrop = false;
      while (backdrop) {
        var color = window.getComputedStyle(backdrop).backgroundColor;
        if (color && color !== 'transparent' && !/rgba\([^)]*,\s*0\s*\)$/.test(color)) { copy.style.backgroundColor = color; opaqueBackdrop = true; break; }
        backdrop = backdrop.parentElement;
      }
      if (articleMode && articleMode !== 'selection' && !opaqueBackdrop) {
        // A color-scheme:dark page can have transparent HTML/body on a dark
        // system Canvas. That implicit canvas is lost in a light note viewer.
        var foreground = copy.style.color.match(/^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
        copy.style.backgroundColor = foreground && Math.min(+foreground[1], +foreground[2], +foreground[3]) > 200 ? '#18191b' : '#fff';
      }
      // Wikipedia supplies both accessibility MathML and fallback images in the
      // same element. Keep one semantic formula, not MathML plus a failed image.
      copy.querySelectorAll('.MathJax_Preview').forEach(function (item) {
        var sibling = item.nextElementSibling;
        if (sibling && sibling.matches(formulaRoots)) item.remove();
      });
      copy.querySelectorAll(formulaRoots).forEach(function (root) {
        if (copy.contains(root)) normalizeMath(root, originalNodes.get(root));
      });
      copy.querySelectorAll('.MathJax_Preview,.MJX_Assistive_MathML,mjx-assistive-mml').forEach(function (item) {
        if (!normalizeMath(item, originalNodes.get(item))) item.remove();
      });
      copy.querySelectorAll('math').forEach(function (item) {
        if (!item.closest('.wiz-clip-formula')) normalizeMath(item, originalNodes.get(item));
      });
      copy.querySelectorAll('pre,code').forEach(function (item) {
        item.style.fontFamily = 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace';
        item.style.fontWeight = '400'; item.style.lineHeight = '1.5'; item.style.tabSize = '4';
        if (item.localName === 'pre') {
          item.style.whiteSpace = 'pre-wrap'; item.style.overflowWrap = 'anywhere'; item.style.wordBreak = 'normal';
          item.style.padding = '12px'; item.style.fontSize = '13px';
          var foreground = item.style.color.match(/^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
          if (!item.style.backgroundColor || item.style.backgroundColor === 'rgba(0, 0, 0, 0)') {
            item.style.backgroundColor = foreground && Math.min(+foreground[1], +foreground[2], +foreground[3]) > 200 ? '#1e1f22' : '#f5f6f8';
          }
        } else if (item.closest('pre')) {
          item.style.whiteSpace = 'inherit'; item.style.fontSize = 'inherit'; item.style.backgroundColor = 'transparent';
        } else {
          item.style.whiteSpace = 'break-spaces';
          if (articleMode === 'selection') item.style.color = 'inherit';
        }
        item.querySelectorAll('*').forEach(function (token) {
          token.style.fontFamily = 'inherit'; token.style.fontSize = 'inherit'; token.style.lineHeight = 'inherit';
          token.style.whiteSpace = 'inherit'; token.style.fontWeight = 'inherit';
        });
      });
      copy.querySelectorAll('script,style,iframe,object,embed,input,button,select,textarea,template,link,meta,base').forEach(function (item) { item.remove(); });
      var walker = document.createTreeWalker(copy, NodeFilter.SHOW_COMMENT), comments = [];
      while (walker.nextNode()) comments.push(walker.currentNode);
      comments.forEach(function (item) { item.remove(); });
      copy.querySelectorAll('img').forEach(function (item) {
        var original = originalNodes.get(item), raw = original ? (original.currentSrc || original.src) : item.getAttribute('src');
        if (original && original.isConnected) {
          var computed = window.getComputedStyle(original);
          if (computed.display === 'none' || computed.visibility === 'hidden') { item.remove(); return; }
        }
        item.removeAttribute('srcset'); item.removeAttribute('sizes');
        item.removeAttribute('data-wiz-clip-resource');
        if (original && original.complete && original.naturalWidth && original.naturalWidth * original.naturalHeight <= 2000000) {
          try {
            var canvas = document.createElement('canvas'); canvas.width = original.naturalWidth; canvas.height = original.naturalHeight;
            canvas.getContext('2d').drawImage(original, 0, 0);
            var data = canvas.toDataURL('image/png');
            if (data.length < 500000 && embedded + data.length < 2000000) { raw = data; embedded += data.length; }
          } catch (_) { /* Cross-origin capture uses the native downloader. */ }
        }
        if (/^data:image\/(png|jpeg|gif|webp);base64,[A-Za-z0-9+/=]+$/.test(raw || '')) { item.setAttribute('src', raw); return; }
        try {
          var address = new URL(raw || '', document.baseURI);
          if (!raw || address.protocol !== 'https:' || address.username || address.password) throw new Error('unsafe image');
          var id = resources.indexOf(address.href);
          if (id < 0) { if (resources.length >= 48) throw new Error('too many images'); id = resources.push(address.href) - 1; }
          item.setAttribute('src', address.href); item.setAttribute('data-wiz-clip-resource', String(id));
        } catch (_) {
          var fallback = document.createElement('a'); fallback.textContent = item.getAttribute('alt') || '原图';
          fallback.setAttribute('href', location.href); fallback.setAttribute('title', '图片未能嵌入，请查看原网页');
          item.replaceWith(fallback); warnings++;
        }
      });
      function clean(root) {
        Array.from(root.children).forEach(function (item) {
          var tag = item.localName.toLowerCase();
          if (tag === 'svg' || tag === 'canvas') {
            var fallback = document.createElement('a'); fallback.textContent = '图形';
            fallback.setAttribute('href', location.href); fallback.setAttribute('title', '图形未能静态保存，请查看原网页');
            item.replaceWith(fallback); warnings++; return;
          }
          clean(item);
          if (!htmlTags.has(tag) && !mathTags.has(tag)) { item.replaceWith.apply(item, Array.from(item.childNodes)); return; }
          Array.from(item.attributes).forEach(function (attr) {
            var name = attr.name.toLowerCase(), value = attr.value;
            var allow = ['id', 'class', 'style', 'alt', 'title', 'lang', 'dir', 'colspan', 'rowspan', 'width', 'height'].indexOf(name) >= 0;
            if (name === 'data-wiz-clip-resource' && tag === 'img' && /^\d+$/.test(value)) allow = true;
            if (mathTags.has(tag) && ['xmlns', 'display', 'encoding', 'mathvariant', 'mathsize', 'mathcolor', 'mathbackground', 'displaystyle', 'scriptlevel', 'columnalign', 'rowalign', 'columnspacing', 'rowspacing', 'stretchy', 'fence', 'separator', 'accent', 'accentunder', 'linethickness', 'lspace', 'rspace'].indexOf(name) >= 0) allow = true;
            if (name === 'href' && tag === 'a') {
              try { var url = new URL(value, document.baseURI); allow = ['http:', 'https:'].indexOf(url.protocol) >= 0 && !url.username && !url.password; if (allow) item.setAttribute(name, url.href); }
              catch (_) { allow = false; }
            }
            if (name === 'src' && tag === 'img') allow = true;
            if (name === 'style' && allow) {
              // Selected ranges are detached, so their original inline styles
              // have not necessarily been replaced with computed properties.
              item.setAttribute('style', value.split(';').filter(function (declaration) {
                var colon = declaration.indexOf(':'), key = declaration.slice(0, colon).trim().toLowerCase();
                var val = declaration.slice(colon + 1).trim();
                return colon > 0 && properties.concat(['max-width','height']).indexOf(key) >= 0 && val.length <= 160
                  && !/url\s*\(|expression\s*\(|[{}<>\\]/i.test(val);
              }).join(';'));
            }
            if (name === 'style' && mathTags.has(tag)) allow = false;
            if (!allow || /^on/i.test(name)) item.removeAttribute(attr.name);
          });
        });
      }
      clean(copy);
      if (articleMode === 'selection') {
        [copy].concat(Array.from(copy.querySelectorAll('*'))).forEach(function (item) {
          if (mathTags.has(item.localName) || item.closest('pre,code,table,mark')) return;
          item.style.removeProperty('background-color');
          // Dark-page white text must not become invisible on the note canvas.
          var color = item.style.color.match(/^rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/);
          if (color && Math.min(+color[1], +color[2], +color[3]) > 200) item.style.color = 'inherit';
        });
        copy.style.color = '#202124';
      }
      var wrapper = document.createElement('div'); wrapper.setAttribute('style', copy.getAttribute('style') || '');
      wrapper.innerHTML = copy.innerHTML; return wrapper.outerHTML;
    }
    try {
      var selection = window.getSelection(), selected = selectedFragment(selection);
      var root = contentRoot();
      var page = root.node ? snapshot(root.node, root.wiki ? 'wiki' : root.forum ? 'forum' : 'article') : '';
      if (root.wiki && page) {
        // Keep provenance/license text compactly rather than copying all site
        // footer menus, badges, last-edit controls and their computed spacing.
        var source = document.createElement('div'), link = document.createElement('a');
        source.setAttribute('style', 'margin-top:20px;padding:8px 0;font-size:13px;line-height:1.5');
        link.href = location.href; link.textContent = document.title || 'Wikipedia'; source.appendChild(link);
        var license = document.querySelector('#footer-info-copyright');
        if (license && !root.node.contains(license)) {
          var notice = document.createElement('div'); notice.innerHTML = snapshot(license);
          notice.querySelectorAll('*').forEach(function (item) { item.removeAttribute('style'); });
          source.appendChild(notice);
        }
        page += source.outerHTML;
      }
      var chosen = selected.node.childNodes.length ? snapshot(selected.node, 'selection', selected.sources) : '';
      if (new Blob([page]).size > 8 * 1024 * 1024) page = '';
      if (new Blob([chosen]).size > 8 * 1024 * 1024) chosen = '';
      args.completionFunction({title: document.title, url: location.href, pageHTML: page, selectionHTML: chosen, resources: resources,
        formulaCount: formulaCount, warnings: warnings,
        text: (document.body ? document.body.innerText : '').slice(0, 50000), selectionText: selection ? selection.toString().slice(0, 50000) : ''});
    } catch (_) { args.completionFunction({title: document.title, url: location.href, pageHTML: '', selectionHTML: ''}); }
  }
};
