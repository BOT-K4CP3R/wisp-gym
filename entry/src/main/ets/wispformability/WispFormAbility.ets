import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from '../app/AppModel';

const TAG = 'WispForm';
const DOMAIN = 0x0011;

// Runs in the widget process. Every entry point re-reads storage from disk first, because
// the app writes from another process and Preferences caches per process.
export default class WispFormAbility extends FormExtensionAbility {
  private model(): AppModel {
    const m = AppModel.get();
    m.init(this.context);
    m.reloadFromDisk();
    return m;
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    const m = this.model();
    const formId = want.parameters !== undefined ? (want.parameters['ohos.extra.param.key.form_identity'] as string) : '';
    if (formId) {
      m.registerForm(formId);
    }
    hilog.info(DOMAIN, TAG, 'onAddForm %{public}s', formId);
    return formBindingData.createFormBindingData(m.widgetData());
  }

  onCastToNormalForm(formId: string): void {
    this.model().registerForm(formId);
  }

  onUpdateForm(formId: string): void {
    const m = this.model();
    m.registerForm(formId);
    m.pushWidget();
  }

  onChangeFormVisibility(newStatus: Record<string, number>): void {
    // Becoming visible is a good moment to bring recovery and mood up to date.
    this.model().pushWidget();
  }

  onFormEvent(formId: string, message: string): void {
    this.model().pushWidget();
  }

  onRemoveForm(formId: string): void {
    this.model().unregisterForm(formId);
  }
}
