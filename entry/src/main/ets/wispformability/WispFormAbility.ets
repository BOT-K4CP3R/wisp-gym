import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from '../app/AppModel';

const TAG = 'WispForm';
const DOMAIN = 0x0011;

export default class WispFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    AppModel.get().init(this.context);
    const formId = want.parameters !== undefined ? (want.parameters['ohos.extra.param.key.form_identity'] as string) : '';
    if (formId) {
      AppModel.get().registerForm(formId);
    }
    hilog.info(DOMAIN, TAG, 'onAddForm %{public}s', formId);
    return formBindingData.createFormBindingData(AppModel.get().widgetData());
  }

  onUpdateForm(formId: string): void {
    AppModel.get().init(this.context);
    AppModel.get().registerForm(formId);
    AppModel.get().pushWidget();
  }

  onRemoveForm(formId: string): void {
    AppModel.get().unregisterForm(formId);
  }
}
