if (window.__olMenuToggleInstalled) {
  console.log('menu_toggle.js already installed');
} else {
  window.__olMenuToggleInstalled = true;
function attachHandlers() {
    if ($(document.body).hasClass("OLReaderInited")) return;

    $.fn.bindFirst = function(name, fn) {
        this.on(name, fn);
        this.each(function() {
            var handlers = $._data(this, 'events')[name.split('.')[0]];
            var handler = handlers.pop();
            handlers.splice(0, 0, handler);
        });
    };

    // Handle tap outside page image
    $("#BookReader").on('click', function (e) {
        if ($(e.target).hasClass("br-mode-2up__root") ||
            $(e.target).hasClass("br-mode-1up__root") ||
            $(e.target).hasClass("BRpageview") ) {
                toggleNav('web');
        }
    });

    $('button').on('click', function (e) {
        var name = $(this).text().trim();
        OLReader.postMessage(JSON.stringify({type: name}));
    });

    (function(){
        var proxied = br.getIdealSpreadSize;
        br.getIdealSpreadSize = function() {
            var data = proxied.apply(this, arguments);
            if ($("#BookReader").hasClass("readerFullScreen")) {
                data.height = data.height > 1 ? data.height + 15 : 1;
                data.width = data.width > 1 ? data.width + 11 : 1;
            }
            return data;
        };
    })();

    let touchStart = [];
    let touchEnd = [];

    $("#IABookReaderWrapper").on('touchstart', function (e) {
        //console.log("targetTouches=" + e.originalEvent.targetTouches.length);
        if (br.mode === 2 && e.originalEvent.targetTouches.length == 1) {
            touchStart = e.originalEvent.targetTouches[0];
        }
    });

    $("#IABookReaderWrapper").on('touchend', function (e) {
        //console.log("changedTouches=" + e.originalEvent.changedTouches.length);
        if (br.mode === 2 && e.originalEvent.changedTouches.length == 1) {
            touchEnd = e.originalEvent.changedTouches[0];
            //console.log("Y=" + Math.abs(touchStart.screenY - touchEnd.screenY));
            //console.log("X=" + Math.abs(touchStart.screenX - touchEnd.screenX));
            if (Math.abs(touchStart.screenY - touchEnd.screenY) < Math.abs(touchStart.screenX - touchEnd.screenX)) {
                if (touchEnd.screenX < touchStart.screenX) br.right();
                if (touchEnd.screenX > touchStart.screenX) br.left();
            }
        }
    });

    if (br.mode === 2) br.trigger("2PageViewSelected");
    $(document.body).addClass("OLReaderInited");
}

function attachLeafEdgeHandler() {
    console.log('attachLeafEdgeHandler');
    setTimeout(function() {
        if (!$("br-leaf-edges").length || $("div.br-mode-2up__book").hasClass("hasPageChangeDialog")) return;
        $("div.br-mode-2up__book").bindFirst('click', e => {
            if ($(e.target).hasClass("br-mode-2up__leafs")) {
                $(br.twoPagePopUp).hide();
                if (!confirm("Change page?")) {
                    e.stopImmediatePropagation();
                    return false;
                }
            }
        });
        $("div.br-mode-2up__book").addClass("hasPageChangeDialog");
    }, 2000);
}

function toggleNav(source) {
    console.log('toggleNav(' + source + ')');
    if ($("#BookReader").hasClass("readerFullScreen")) {
     OLReader.postMessage(JSON.stringify({type: 'ShowingNav'}));
     //tools
     $($("ia-book-theater")[0].shadowRoot.firstElementChild.shadowRoot.firstElementChild.firstElementChild.shadowRoot.firstElementChild.getElementsByTagName('nav')[0]).show();
     //header
     $($("ia-book-theater")[0].shadowRoot.firstElementChild.shadowRoot.firstElementChild.firstElementChild.shadowRoot.firstElementChild.firstElementChild).show();
     //footer
     if ($("div.BRfooter").is(":hidden")) $("div.BRfooter").fadeToggle("slow");
    } else {
     OLReader.postMessage(JSON.stringify({type: 'HidingNav'}));
     br.onePage.autofit = 'height';
     //tools
     $($("ia-book-theater")[0].shadowRoot.firstElementChild.shadowRoot.firstElementChild.firstElementChild.shadowRoot.firstElementChild.getElementsByTagName('nav')[0]).hide();
     //header
     $($("ia-book-theater")[0].shadowRoot.firstElementChild.shadowRoot.firstElementChild.firstElementChild.shadowRoot.firstElementChild.firstElementChild).hide();
     //footer
     if ($("div.BRfooter").is(":visible")) $("div.BRfooter").fadeToggle("slow");
    }
    $("#BookReader").toggleClass("readerFullScreen");
}

// Apply saved visual adjustments from Dart
function applyVisualAdjustments(adjustments, depth=0) {
    if (depth > 10) {
        console.log('applyVisualAdjustments: max depth reached');
        return;
    }
    try {
        const theater = $("ia-book-theater")[0];
        if (!theater || !theater.shadowRoot) {
            setTimeout(function() { applyVisualAdjustments(adjustments, depth + 1); }, 500);
            return;
        }
        const bookNavigator = theater.shadowRoot.firstElementChild.shadowRoot.firstElementChild.firstElementChild.getElementsByTagName('book-navigator')[0];
        if (!bookNavigator || !bookNavigator.menuProviders || !bookNavigator.menuProviders['visualAdjustments']) {
            setTimeout(function() { applyVisualAdjustments(adjustments, depth + 1); }, 500);
            return;
        }

        const vaProvider = bookNavigator.menuProviders['visualAdjustments'];
        if (adjustments.options) {
            vaProvider.component.values[0] = adjustments.options;
        }
        if (adjustments.activeCount !== undefined) {
            vaProvider.activeCount = adjustments.activeCount;
        }
        // Trigger the adjustment change to apply the settings
        vaProvider.onAdjustmentChange({detail: adjustments});
        console.log('Visual adjustments applied successfully');
    } catch (e) {
        console.log('applyVisualAdjustments error: ' + e);
        setTimeout(function() { applyVisualAdjustments(adjustments, depth + 1); }, 500);
    }
}

document.addEventListener('BookReader:PostInit', (e) => {
    OLReader.postMessage(JSON.stringify({type: 'PostInit'}));
    console.log('BookReader:PostInit');
    attachHandlers();
});

document.addEventListener('BRJSIA:PostInit', (e) => {
    OLReader.postMessage(JSON.stringify({type: 'PostInit'}));
    console.log('BRJSIA:PostInit');
    attachHandlers();
    // Handle case of br.init never being called on some devices
    setTimeout(function() {
        if (br.init.initComplete !== true) {
            console.log('Re-initing bookreader');
            br.init();
        }
    }, 2000);
});

const loadPage = new Event('loadPage');

document.addEventListener('loadPage', (e) => {
    setTimeout(function() {
        if (!$("br-leaf-edges").length || $("div.br-mode-2up__book").hasClass("hasPageChangeDialog")) return;
        $("div.br-mode-2up__book").bindFirst('click', e => {
            if ($(e.target).hasClass("br-mode-2up__leafs")) {
                $(br.twoPagePopUp).hide();
                if (!confirm("Change page?")) {
                    e.stopImmediatePropagation();
                    return false;
                }
            }
        });
        $("div.br-mode-2up__book").addClass("hasPageChangeDialog");
    }, 2000);
});

document.addEventListener('BookReader:resize', (e) => {
    console.log('BookReader:resize');
    if (br.mode === 2) br.trigger("2PageViewSelected");
});

document.addEventListener('IABookReader:BrowsingHasExpired', (e) => {
    console.log('IABookReader:BrowsingHasExpired');
    OLReader.postMessage(JSON.stringify({type: 'LoanExpired'}));
});

document.addEventListener('visualAdjustmentOptionChanged', (e) => {
    OLReader.postMessage(JSON.stringify({type: 'visualAdjustmentOptionChanged', detail: e.detail }));
    // Also send in format for saving/restoring
    OLReader.postMessage(JSON.stringify({
        type: 'VisualAdjustmentsChanged',
        adjustments: {
            options: e.detail.options,
            activeCount: e.detail.activeCount
        }
    }));
});

/* Handle case where error message loads instead of Bookreader */
if (!document.getElementById('BookReader')) {
    OLReader.postMessage(JSON.stringify({type: 'NoReader'}));
}

/* Handle case where Bookreader initialization is complete before this script loads */
if (typeof br != "undefined" && br.init.initComplete === true) {
    OLReader.postMessage(JSON.stringify({type: 'PostInit'}));
    attachHandlers();
    console.log('Init already complete');
}

console.log('Javascript loaded');
}