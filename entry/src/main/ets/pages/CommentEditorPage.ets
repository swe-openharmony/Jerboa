// Page: CommentEditorPage — create a top-level comment (parentCommentId empty) or
// reply to a comment. On submit the body is handed back to PostActivityPage via
// AppStorage and the page is popped; PostActivityPage appends it to the tree.

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'CommentEditorPage';

@Entry
@Component
struct CommentEditorPage {
  @State private body: string = '';
  @State private parentCommentId: string = '';
  @State private postId: string = '';
  @State private communityId: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    if (params) {
      this.parentCommentId = params.parentCommentId ?? '';
      this.postId = params.postId ?? '';
      this.communityId = params.communityId ?? '';
    }
    hilog.info(0x0000, TAG, 'editor parent=%{public}s', this.parentCommentId);
  }

  private submit(): void {
    if (this.body.trim().length === 0) { return; }
    AppStorage.setOrCreate<string>('jerboaPendingBody', this.body.trim());
    AppStorage.setOrCreate<string>('jerboaPendingParent', this.parentCommentId);
    AppStorage.setOrCreate<string>('jerboaPendingToken', `${Date.now()}`);
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('✕').fontSize(20).fontColor('#1F1F1F').width(44).height(48).textAlign(TextAlign.Center)
          .onClick(() => router.back());
        Text(this.parentCommentId.length > 0 ? 'Reply' : 'Create post')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#1F1F1F').layoutWeight(1).margin({ left: 8 });
        Text('Submit').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1976D2')
          .padding({ left: 12, right: 16, top: 12, bottom: 12 }).onClick(() => this.submit());
      }
      .width('100%').height(56).alignItems(VerticalAlign.Center).backgroundColor('#FFFFFF');

      TextArea({ placeholder: 'Write a comment…', text: this.body })
        .width('100%').height(180).margin({ top: 8 })
        .onChange((v: string) => { this.body = v; });
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF');
  }
}
