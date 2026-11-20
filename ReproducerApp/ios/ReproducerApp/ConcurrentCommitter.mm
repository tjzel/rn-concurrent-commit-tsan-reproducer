#import "ConcurrentCommitter.h"

#import <QuartzCore/QuartzCore.h>
#import <React-RCTAppDelegate/RCTReactNativeFactory.h>
#import <React-RCTAppDelegate/RCTRootViewFactory.h>
#import <React/RCTScheduler.h>
#import <React/RCTSurfacePresenter.h>
#import <ReactCommon/RCTHost.h>
#import <react/renderer/components/root/RootShadowNode.h>
#import <react/renderer/mounting/ShadowTree.h>
#import <react/renderer/uimanager/UIManager.h>

using namespace facebook::react;

static std::shared_ptr<ShadowNode> cloneSubtree(const ShadowNode &node)
{
  auto children = std::make_shared<std::vector<std::shared_ptr<const ShadowNode>>>();
  for (const auto &child : node.getChildren()) {
    children->push_back(cloneSubtree(*child));
  }
  return node.clone({.children = children});
}

@implementation ConcurrentCommitter {
  RCTReactNativeFactory *_factory;
  CADisplayLink *_displayLink;
}

+ (void)startWithFactory:(RCTReactNativeFactory *)factory
{
  static ConcurrentCommitter *committer;
  committer = [ConcurrentCommitter new];
  committer->_factory = factory;
  committer->_displayLink = [CADisplayLink displayLinkWithTarget:committer selector:@selector(onFrame)];
  [committer->_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)onFrame
{
  RCTScheduler *scheduler = _factory.rootViewFactory.reactHost.surfacePresenter.scheduler;
  if (scheduler == nil) {
    return;
  }
  scheduler.uiManager->getShadowTreeRegistry().enumerate([](const ShadowTree &shadowTree, bool &) {
    shadowTree.commit(
        [](const RootShadowNode &root) { return std::static_pointer_cast<RootShadowNode>(cloneSubtree(root)); }, {});
  });
}

@end
