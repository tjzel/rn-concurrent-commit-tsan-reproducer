# React Native Reproducer

> [!IMPORTANT]  
> Do not just **fork** this repository, but use instead the [![Use this template](https://img.shields.io/badge/-Use%20this%20template-brightgreen)](https://github.com/cortinico/reproducer-react-native/generate) button on GitHub.

This is the React Native **reproducer** template. 

You can use this template to create a minimal, complete, and reproducible project that the community can use to understand what's your problem. You can read more about the principles of a good reproducible project [here](https://stackoverflow.com/help/mcve).

This template is up to date with `react-native@latest` as you can find it on [npm](https://www.npmjs.com/package/react-native/v/latest).

## How to use this repository

1. Click on [![Use this template](https://img.shields.io/badge/-Use%20this%20template-brightgreen)](https://github.com/cortinico/reproducer-react-native/generate) button to create a new repository starting from this one.
2. Git clone your repository locally.
3. Edit the project to reproduce the failure you're seeing.
4. Push your changes, so that Github Actions can run the CI.

## ThreadSanitizer reproducer

This app shows two ThreadSanitizer (TSAN) reports on an iOS simulator:

1. [react/react-native#60106](https://github.com/react/react-native/issues/60106): a data race on Yoga `Node::owner_`
   between two overlapping `ShadowTree::commit` calls.
2. [react/react-native#60130](https://github.com/react/react-native/issues/60130): a race between
   `facebook::react::Task::execute` on the JS thread and the destruction of the same `Task` on a Hermes GC thread.

What the app does:

- `ReproducerApp/App.tsx` re-renders a 30 x 7 tree of `View`s and `Text`s in a loop from `useEffect`, so React commits
  from the JS thread (`UIManager::completeSurface`) all the time and the scheduler creates and drops many `Task`s.
- `ReproducerApp/ios/ReproducerApp/ConcurrentCommitter.mm` commits from the main thread on every `CADisplayLink`
  frame. The transaction clones the whole shadow tree, like an animation library that updates props from the UI
  thread. It is started from `SceneDelegate.swift`.

### Steps

Requirements: Xcode, Ruby with bundler, Node and Yarn, and a simulator.

```sh
cd ReproducerApp
yarn
scripts/tsan.sh <simulator udid> [seconds, default 60]
```

`scripts/tsan.sh` runs `pod install` with React Native core built from source
(`RCT_USE_PREBUILT_RNCORE=0 RCT_USE_RN_DEP=0`), so that TSAN instruments it, builds the Release configuration
(the JS bundle is embedded, no Metro) with `-enableThreadSanitizer YES ENABLE_THREAD_SANITIZER=YES`, installs the app,
launches it with `TSAN_OPTIONS="log_path=tsan-reports/tsan halt_on_error=0"`, waits, terminates it and prints the
`SUMMARY:` lines of the reports in `ReproducerApp/tsan-reports/`. Use `SKIP_BUILD=1 scripts/tsan.sh <udid>` to run
again without building.

### Expected output

The Yoga race shows in every run; the `Task` race is intermittent (one run in six locally, 60 s each). Output of a run
that showed both:

```
ThreadSanitizer reports in .../ReproducerApp/tsan-reports:
   2 SUMMARY: ThreadSanitizer: data race YogaLayoutableShadowNode.cpp:130 in facebook::react::YogaLayoutableShadowNode::YogaLayoutableShadowNode(facebook::react::ShadowNode const&, facebook::react::ShadowNodeFragment const&)
   1 SUMMARY: ThreadSanitizer: data race YGNode.cpp:282 in YGNodeGetOwner
   1 SUMMARY: ThreadSanitizer: data race in std::__1::__shared_ptr_emplace<facebook::react::Task, std::__1::allocator<facebook::react::Task>>::__on_zero_shared()
```

Both Yoga summaries are the same race: `updateYogaChildrenOwnersIfNeeded` (inlined into the `YogaLayoutableShadowNode`
clone constructor at line 130) writes the owner of a shared child while the other commit reads or writes it during
layout.
