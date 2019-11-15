# Customizing the Brigade Worker Image

## Three Approaches

1. Use `brigade.json` file to add NPM packages before `brigade.js` executes.

1. Build a new Docker image that extends the default worker and adds additional
   NPM or system-level packages.

1. Build a new Docker image that does something completely different but is
   Brigade-compatible.

### Hello, World!

To get started, we'll consider the "Hello, World!" of Brigade scripts:

```javascript
const { events, Job } = require('brigadier');

events.on('exec', () => {
  var job = new Job("hello-world", 'alpine:3.8');
  job.tasks = [
    "echo 'Hello, World!'"
  ];
  job.run();
});
```

Use `brig project create` to create a new project with the following options:

* __VCS or no-VCS project:__ `no-VCS`
* __Project Name:__ `hello-world`
* __Upload a default brigade.js script:__ `0-hello-world/brigade.js`
* Accept defaults for everything else.

Then:

```console
$ brig run hello-world
```

Unsurprisingly this works.

Our next two examples add some embellishments to this `brigade.js` script that
will require additional NPM packages that aren't included in Brigade's default
worker image.

### Hello, Random!

In this example, we'll amend our script to use a random job name. This will
introduce a dependency on the `uniqueNamesGenerator` NPM package, which isn't
present on Brigade's default worker image.

```javascript
const { events, Job } = require('brigadier');
const { uniqueNamesGenerator, adjectives, animals } = require('unique-names-generator');

events.on('exec', () => {
  randomJobName = uniqueNamesGenerator({
    dictionaries: [adjectives, animals],
    length: 2,
    separator: '-'
  });
  console.log('using job name: ' + randomJobName);
  var job = new Job(randomJobName, 'alpine:3.8');
  job.tasks = [
    'echo "Hello from ' + randomJobName + '."'
  ];
  job.run();
});
```

Use `brig project create` to create a new project with the following options:

* __VCS or no-VCS project:__ `no-VCS`
* __Project Name:__ `hello-random`
* __Upload a default brigade.js script:__ `1-hello-random/brigade.js`
* Accept defaults for everything else.

Then:

```console
$ brig run hello-random
```

Unsurprisingly, this fails.

We can use a `brigade.json` file to instruct the Brigade worker to install
additional NPM packages before executing our script:

```json
{
  "dependencies": {
      "unique-names-generator": "4.0.0"
  }
}
```

```console
$ brig run hello-random --config 1-hello-random/brigade.json
```

### Hello, Colors!

In this example, we'll further amend our script to use some colored output. This
will introduce a dependency on the `colors` NPM package, which isn't present on
Brigade's default worker image.

```javascript
const { events, Job } = require('brigadier');
const { uniqueNamesGenerator, adjectives, animals } = require('unique-names-generator');
const colors = require('colors');

colors.enable();

events.on('exec', () => {
  randomJobName = uniqueNamesGenerator({
    dictionaries: [adjectives, animals],
    length: 2,
    separator: '-'
  });
  console.log(('using job name: ' + randomJobName).green);
  var job = new Job(randomJobName, 'alpine:3.8');
  job.tasks = [
    'echo "Hello from ' + randomJobName + '."'
  ];
  job.run();
});
```

This time, we'll use a custom worker image that "extends" Brigade's default
worker image by adding all the NPM packages we need.

```dockerfile
FROM krancour/brigade-worker:kubecon

RUN yarn add unique-names-generator@4.0.0
RUN yarn add colors@1.4.0
```

__Note: For convenience, I have already built this and pushed it to
`krancour/brigade-worker:colors`.__

Use `brig project create` to create a new project with the following options:

* __VCS or no-VCS project:__ `no-VCS`
* __Project Name:__ `hello-colors`
* __Upload a default brigade.js script:__ `2-hello-colors/brigade.js`
* __Configure advanced options:__ `Y`
  * __Worker image registry or DockerHub org:__ `krancour`
  * __Worker image name:__ `brigade-worker`
  * __Custom worker image tag:__ `colors`
* Accept defaults for everything else.

Then:

```console
$ brig run hello-colors
```

Note that this approach does not constrain you to only adding NPM packages to
your custom image. You could equally add system-level dependencies...

Or...

### Hello, Drake!

There's no reason you cannot build a Brigade-compatible worker that does
something completely new and innovative!

[This bit of Brigade documentation](https://docs.brigade.sh/topics/workers/#environment-variables)
details how you can build a completely custom worker from scratch.

At a high level:

* Consume worker configuration from the same sources as the default worker:
  * [Environment variables](https://docs.brigade.sh/topics/workers/#environment-variables)
  * [Project secret](https://docs.brigade.sh/topics/workers/#environment-variables)
* For each job,
  [name and label](https://docs.brigade.sh/topics/workers/#job-pod-names-and-labels)
  the corresponding pod the same way the default worker would.

My co-worker @carolynvs has requested for Brigade to support
[declarative pipelines](https://github.com/brigadecore/brigade/issues/1024).

Confession time: I don't actually like JavaScript. There's nothing wrong with
it. It just isn't my style. So, I've wanted this feature since long before
@carolynvs requested it... and I've been working on it on the side.

The [brigdrake](https://github.com/lovethedrake/brigdrake) project implements
a custom Brigade worker that supports declarative pipelines based on a (draft)
open specification.

Here's a simple `Drakefile.yaml` that describes a pipeline named `foobar` that
executes jobs named `foo` and `bar` in sequence:

```yaml
specUri: github.com/lovethedrake/drakespec
specVersion: v0.4.0

jobs:

  foo:
    primaryContainer:
      name: echo
      image: alpine:3.8
      command: ["echo"]
      args: ["foo"]

  bar:
    primaryContainer:
      name: echo
      image: alpine:3.8
      command: ["echo"]
      args: ["bar"]

pipelines:

  foobar:
    triggers:
    - specUri: github.com/lovethedrake/drakespec-brig
      specVersion: v1.0.0
      config:
        eventTypes:
        - foobar
    jobs:
    - name: foo
    - name: bar
      dependencies:
      - foo
```

Use `brig project create` to create a new project with the following options:

* __VCS or no-VCS project:__ `no-VCS`
* __Project Name:__ `hello-drake`
* __Upload a default brigade.js script:__ `3-hello-colors/Drakefile.yaml`
* __Configure advanced options:__ `Y`
  * __Worker image registry or DockerHub org:__ `lovethedrake`
  * __Worker image name:__ `brigdrake-worker`
  * __Custom worker image tag:__ `v0.21.0`
  * __Worker command:__ `/brigdrake/bin/brigdrake-worker`
* Accept defaults for everything else.

The `foobar` pipeline described by our `Drakefile.yaml` can be triggered by
a `foobar` event emitted by `brig`:

```console
$ brig run hello-drake --event foobar
```

__Look for this feature to be integrated directly into Brigade itself in
the near-ish future.__

## Wrapping Up

This has been a whirlwind tour of how to customize the Brigade worker.

We used three different approaches:

1. Use `brigade.json` file to add NPM packages before `brigade.js` executes.

1. Build a new Docker image that extends the default worker and adds additional
   NPM or system-level packages.

1. Build a new Docker image that does something completely different but is
   Brigade-compatible.

We applied our custom Docker images on a per-project basis, but note that
nothing stops you from configuring your Brigade installation from using a
custom image as the new default!

## Questions?
