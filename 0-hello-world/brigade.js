const { events, Job } = require('brigadier');

events.on('exec', () => {
  var job = new Job("hello-world", 'alpine:3.8');
  job.tasks = [
    "echo 'Hello, World!'"
  ];
  job.run();
});
