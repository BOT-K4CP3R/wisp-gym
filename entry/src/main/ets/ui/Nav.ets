import { UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

// Parameters passed between pages with the router. A declared class keeps ArkTS object
// literals typed.
export class RouteParams {
  replay?: boolean;
  exercise?: string;
}

// Router calls never throw into the UI: a failed navigation is logged and ignored.
export function navPush(ui: UIContext, url: string, params?: RouteParams): void {
  const p = params === undefined ? new RouteParams() : params;
  ui.getRouter().pushUrl({ url: url, params: p }).catch((e: BusinessError) => {
    hilog.warn(0x0030, 'WispNav', 'push %{public}s failed: %{public}d', url, e.code);
  });
}

export function navReplace(ui: UIContext, url: string): void {
  ui.getRouter().replaceUrl({ url: url }).catch((e: BusinessError) => {
    hilog.warn(0x0030, 'WispNav', 'replace %{public}s failed: %{public}d', url, e.code);
  });
}
