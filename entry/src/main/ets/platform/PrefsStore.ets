import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyValueStore } from '../core/Store';

const TAG = 'WispPrefs';
const DOMAIN = 0x0001;

// Platform implementation of the core KeyValueStore on top of @ohos.data.preferences.
export class PrefsStore extends KeyValueStore {
  private prefs: preferences.Preferences | null = null;

  constructor(context: common.Context) {
    super();
    try {
      this.prefs = preferences.getPreferencesSync(context, { name: 'wisp' });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preferences unavailable: %{public}s', JSON.stringify(e));
    }
  }

  get(key: string): string {
    if (this.prefs === null) {
      return '';
    }
    try {
      return this.prefs.getSync(key, '') as string;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'get failed: %{public}s', JSON.stringify(e));
      return '';
    }
  }

  put(key: string, value: string): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(key, value);
      this.prefs.flush().catch((e: Error) => {
        hilog.error(DOMAIN, TAG, 'flush failed: %{public}s', e.message);
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'put failed: %{public}s', JSON.stringify(e));
    }
  }
}
