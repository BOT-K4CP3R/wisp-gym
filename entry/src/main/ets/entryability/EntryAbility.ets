import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppModel, NAV_TARGET } from '../app/AppModel';

const DOMAIN = 0x0000;
const TAG = 'WispAbility';
const WINDOW_BG = '#0A0A0C';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      // The design is dark-only; system components (dialogs, sheets, inputs) follow it.
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode: %{public}s', JSON.stringify(err));
    }
    AppModel.get().init(this.context);
    AppModel.get().attachUiContext(this.context);
    this.route(want);
  }

  // A widget tap while the app is already running.
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.route(want);
  }

  private route(want: Want): void {
    const params = want.parameters;
    if (params === undefined) {
      return;
    }
    const target = params['target'] as string;
    if (typeof target === 'string' && target.length > 0) {
      // A changing value so the same target can fire twice in a row.
      AppStorage.setOrCreate<string>(NAV_TARGET, target + '@' + Date.now());
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const start = AppModel.get().profile().onboarded ? 'pages/Index' : 'pages/Onboarding';
    windowStage.loadContent(start, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content: %{public}s', JSON.stringify(err));
        return;
      }
      // Style the system bars to blend into the app (after the content exists).
      windowStage.getMainWindow().then((win: window.Window) => {
        win.setWindowBackgroundColor(WINDOW_BG);
        return win.setWindowSystemBarProperties({
          statusBarColor: WINDOW_BG,
          statusBarContentColor: '#FFFFFF',
          navigationBarColor: WINDOW_BG,
          navigationBarContentColor: '#FFFFFF'
        });
      }).catch((e: Error) => {
        hilog.warn(DOMAIN, TAG, 'system bar styling failed: %{public}s', e.message);
      });
    });
  }

  onBackground(): void {
    // Recovery changes with time: refresh the widget whenever the user leaves the app.
    AppModel.get().pushWidget();
  }
}
