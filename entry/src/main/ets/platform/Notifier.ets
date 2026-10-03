import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'WispNotify';
const DOMAIN = 0x0004;

export class Notifier {
  private context: common.UIAbilityContext;
  private enabled: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async ensureEnabled(): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(this.context);
      this.enabled = true;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'notifications not enabled: %{public}s', JSON.stringify(e));
      this.enabled = false;
    }
    return this.enabled;
  }

  async post(id: number, title: string, text: string): Promise<void> {
    if (!this.enabled) {
      return;
    }
    try {
      await notificationManager.publish({
        id: id,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title: title, text: text }
        }
      });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'publish failed: %{public}s', JSON.stringify(e));
    }
  }
}
