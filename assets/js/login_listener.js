window.addEventListener(
  'message',
  function(e) {
      if (e.data.type == 's3-keys') {
          OLReader.postMessage(JSON.stringify({value: JSON.stringify(e.data.s3)}));
      }
  },
  false
);
window.addEventListener('load', function(ev) {

});

  // Download main.dart.js
  console.log('loadEntrypoint');
  _flutter.loader.loadEntrypoint({
    entrypointUrl: "/main.dart.js", // <-- THIS LINE
    serviceWorker: {
      serviceWorkerVersion: serviceWorkerVersion,
      serviceWorkerUrl: "/flutter_service_worker.js?v=", // <-- THIS LINE
    },
    onEntrypointLoaded: function(engineInitializer) {
      engineInitializer.initializeEngine().then(function(appRunner) {
        appRunner.runApp();
      });
    }
  });