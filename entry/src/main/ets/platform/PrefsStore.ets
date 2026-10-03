import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyValueStore } from '../core/Store';

const TAG = 'WispPrefs';
const DOMAIN = 0x0001;

// Platform implementation of the core KeyValueStore on top of @ohos.data.preferences.
// Preferences keeps a per-process cache. The widget runs in its own process, so it calls
// reload() to drop that cache and read what the app wrote to disk.
export class PrefsStore extends KeyValueStore {
  private prefs: preferences.Preferences | null = null;
  private context: common.Context;
  private name: string;

  constructor(context: common.Context, name: string) {
    super();
    this.context = context;
    this.name = name;
    this.open();
  }

  private open(): void {
    try {
      this.prefs = preferences.getPreferencesSync(this.context, { name: this.name });
    } catch (e) {
      this.prefs = null;
      hilog.error(DOMAIN, TAG, 'preferences unavailable: %{public}s', JSON.stringify(e));
    }
  }

  reload(): void {
    try {
      preferences.removePreferencesFromCacheSync(this.context, { name: this.name });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'cache eviction failed: %{public}s', JSON.stringify(e));
    }
    this.open();
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
