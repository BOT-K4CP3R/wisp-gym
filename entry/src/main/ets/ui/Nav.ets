import { UIContext } from '@kit.ArkUI';

// Tab navigation shared by the Home / Week / Insights pages. Tabs replace each other (no
// back-stack growth); "train" opens the full-screen workout on top.
export function goTab(ui: UIContext, current: string, target: string): void {
  if (target === current) {
    return;
  }
  const router = ui.getRouter();
  if (target === 'train') {
    router.pushUrl({ url: 'pages/Workout' });
    return;
  }
  const url = target === 'home' ? 'pages/Index' : (target === 'week' ? 'pages/Week' : 'pages/Why');
  router.replaceUrl({ url: url });
}
