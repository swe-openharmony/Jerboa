// Page: PostActivityPage — Lemmy post detail: post body, comment tree, voting/saving,
// subscribe, comment sort, collapse/actions toggles, more-options, create/reply entries.

import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MockDataSource } from '../common/MockDataSource';

const TAG = 'PostActivityPage';

interface RawComment {
  id: string;
  parentId: string;
  author: string;
  body: string;
  score: number;
  myVote: number;      // -1, 0, +1
  saved: boolean;
  timeText: string;
  edited: boolean;
  editTimeText: string;
  hotRank: number;
  createdOrder: number;
  controversy: number;
  hasMoreChildren: boolean;
}

interface SessionInfo { downvotesEnabled: boolean; isGuest: boolean; }

interface PostInfo {
  postId: string;
  communityId: string;
  communityName: string;
  communityStatus: string;
  bannerTitle: string;
  bannerUsersText: string;
  subscribed: boolean;
  postAuthor: string;
  postTimeText: string;
  postTitle: string;
  postBody: string;
  postScore: number;
  myVote: number;
  saved: boolean;
  featuredLocal: boolean;
  featuredCommunity: boolean;
}

interface PostFile {
  session: SessionInfo;
  post: PostInfo;
  comments: RawComment[];
  moreReplies: Record<string, RawComment[]>;
}

// One rendered row of the flattened comment tree.
interface DisplayNode {
  kind: string;          // 'comment' | 'gone' | 'more'
  id: string;
  comment: RawComment | null;
  depth: number;
  descendantCount: number;
  parentForMore: string;
  key: string;
}

const SORTS: string[] = ['Hot', 'Top', 'New', 'Old', 'Controversial'];

@Entry
@Component
struct PostActivityPage {
  // session
  @State private downvotesEnabled: boolean = true;
  @State private isGuest: boolean = false;

  // community / post
  @State private communityName: string = '';
  @State private bannerTitle: string = '';
  @State private bannerUsersText: string = '';
  @State private subscribed: boolean = false;
  @State private postAuthor: string = '';
  @State private postTimeText: string = '';
  @State private postTitle: string = '';
  @State private postBody: string = '';
  @State private postScore: number = 0;
  @State private myPostVote: number = 0;
  @State private bookmarked: boolean = false;
  @State private featuredLocal: boolean = false;
  @State private featuredCommunity: boolean = false;
  private postId: string = '';
  private communityId: string = '';

  // comments + view state
  @State private comments: RawComment[] = [];
  @State private moreReplies: Record<string, RawComment[]> = {};
  @State private sortBy: string = 'Hot';
  @State private collapsedIds: string[] = [];
  @State private actionsHiddenIds: string[] = [];
  @State private expandedMoreIds: string[] = [];

  // overlays
  @State private sortMenuOpen: boolean = false;
  @State private moreMenuOpen: boolean = false;
  @State private moreTarget: string = '';     // 'post' or a comment id
  @State private sourceDialogOpen: boolean = false;
  @State private sourceText: string = '';
  @State private guardBannerVisible: boolean = false;
  @State private errorBannerVisible: boolean = false;
  @State private isRefreshing: boolean = false;
  @State private loading: boolean = true;
  private simulateWriteFail: boolean = false;

  private newCommentSeq: number = 0;
  private lastConsumedToken: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    if (params && params.postId) {
      this.postId = params.postId;
      hilog.info(0x0000, TAG, 'enter post %{public}s', this.postId);
    }
    this.loadPost();
  }

  // A submitted comment from the editor page is handed back via AppStorage.
  onPageShow(): void {
    const body = AppStorage.get<string>('jerboaPendingBody');
    const token = AppStorage.get<string>('jerboaPendingToken');
    if (body !== undefined && token !== undefined && token.length > 0 && token !== this.lastConsumedToken) {
      const parentId = AppStorage.get<string>('jerboaPendingParent') ?? '';
      this.appendComment(parentId, body);
      this.lastConsumedToken = token;
    }
  }

  private async loadPost(): Promise<void> {
    this.loading = true;
    hilog.info(0x0000, TAG, 'LOAD_START');
    try {
      const data = await MockDataSource.loadJson<PostFile>(this, 'mock_post.json');
      this.downvotesEnabled = data.session.downvotesEnabled;
      this.isGuest = data.session.isGuest;
      const p: PostInfo = data.post;
      this.postId = p.postId;
      this.communityId = p.communityId;
      this.communityName = p.communityName;
      this.bannerTitle = p.bannerTitle;
      this.bannerUsersText = p.bannerUsersText;
      this.subscribed = p.subscribed;
      this.postAuthor = p.postAuthor;
      this.postTimeText = p.postTimeText;
      this.postTitle = p.postTitle;
      this.postBody = p.postBody;
      this.postScore = p.postScore;
      this.myPostVote = p.myVote;
      this.bookmarked = p.saved;
      this.featuredLocal = p.featuredLocal;
      this.featuredCommunity = p.featuredCommunity;
      this.comments = data.comments;
      this.moreReplies = data.moreReplies;
      // Deterministic test-mode overrides (see EntryAbility.captureTestParams):
      //   --ps session guest   → anonymous guest (write-guard banner)
      //   --ps session nodown  → downvotesEnabled = false (▼ not rendered)
      //   --ps writefail 1     → every write optimistically applies then rolls back
      const ts = AppStorage.get<string>('test_session');
      if (ts === 'guest') { this.isGuest = true; }
      if (ts === 'nodown') { this.downvotesEnabled = false; }
      this.simulateWriteFail = AppStorage.get<string>('test_writefail') === '1';
      hilog.info(0x0000, TAG, 'loaded %{public}d comments', this.comments.length);
    } catch (e) {
      hilog.error(0x0000, TAG, 'load failed: %{public}s', String(e));
      this.comments = [];
    }
    this.loading = false;
    hilog.info(0x0000, TAG, 'LOAD_DONE');
  }

  // ── helpers ──────────────────────────────────────────────────────────
  private toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 1500 });
  }

  // Anonymous guard: returns true if the write was blocked (caller should stop).
  private guarded(): boolean {
    if (this.isGuest) {
      this.guardBannerVisible = true;
      return true;
    }
    return false;
  }

  private cmp(a: RawComment, b: RawComment): number {
    if (this.sortBy === 'Top') { return b.score - a.score; }
    if (this.sortBy === 'New') { return b.createdOrder - a.createdOrder; }
    if (this.sortBy === 'Old') { return a.createdOrder - b.createdOrder; }
    if (this.sortBy === 'Controversial') { return b.controversy - a.controversy; }
    return b.hotRank - a.hotRank;   // Hot
  }

  private childrenOf(parentId: string): RawComment[] {
    const arr: RawComment[] = this.comments.filter((c: RawComment) => c.parentId === parentId);
    arr.sort((a: RawComment, b: RawComment): number => this.cmp(a, b));
    return arr;
  }

  private descendantCount(id: string): number {
    let n: number = 0;
    const kids: RawComment[] = this.comments.filter((c: RawComment) => c.parentId === id);
    for (const k of kids) { n += 1 + this.descendantCount(k.id); }
    return n;
  }

  private goneParents(): string[] {
    const ids: Set<string> = new Set<string>();
    for (const c of this.comments) { ids.add(c.id); }
    const gone: string[] = [];
    for (const c of this.comments) {
      if (c.parentId.length > 0 && !ids.has(c.parentId) && gone.indexOf(c.parentId) < 0) {
        gone.push(c.parentId);
      }
    }
    return gone;
  }

  private nodeKey(c: RawComment): string {
    const col: string = this.collapsedIds.indexOf(c.id) >= 0 ? 'C' : 'E';
    const act: string = this.actionsHiddenIds.indexOf(c.id) >= 0 ? 'H' : 'V';
    return `${c.id}|${c.score}|${c.myVote}|${c.saved ? 'S' : '_'}|${col}|${act}`;
  }

  private emit(out: DisplayNode[], c: RawComment, depth: number): void {
    const collapsed: boolean = this.collapsedIds.indexOf(c.id) >= 0;
    out.push({
      kind: 'comment', id: c.id, comment: c, depth: depth,
      descendantCount: this.descendantCount(c.id), parentForMore: '', key: this.nodeKey(c)
    });
    if (collapsed) { return; }
    const kids: RawComment[] = this.childrenOf(c.id);
    for (const k of kids) { this.emit(out, k, depth + 1); }
    if (c.hasMoreChildren && this.expandedMoreIds.indexOf(c.id) < 0) {
      out.push({
        kind: 'more', id: `more:${c.id}`, comment: null, depth: depth + 1,
        descendantCount: 0, parentForMore: c.id, key: `more:${c.id}`
      });
    }
  }

  private displayList(): DisplayNode[] {
    const out: DisplayNode[] = [];
    const top: RawComment[] = this.childrenOf('');
    for (const c of top) { this.emit(out, c, 0); }
    // gone-parent placeholders (rendered top-level), with their orphans below
    for (const gp of this.goneParents()) {
      out.push({
        kind: 'gone', id: `gone:${gp}`, comment: null, depth: 0,
        descendantCount: 0, parentForMore: '', key: `gone:${gp}`
      });
      const orphans: RawComment[] = this.childrenOf(gp);
      for (const o of orphans) { this.emit(out, o, 1); }
    }
    return out;
  }

  // ── post action bar state machine (shared model, target = post) ──────
  // Optimistic-write + rollback template: snapshot, apply locally, and if the (simulated)
  // remote write fails, restore the snapshot and surface an error banner.
  private rollbackIfFailed(snapScore: number, snapVote: number): void {
    if (this.simulateWriteFail) {
      this.postScore = snapScore;
      this.myPostVote = snapVote;
      this.errorBannerVisible = true;
      hilog.warn(0x0000, TAG, 'WRITE_ROLLBACK post score=%{public}d vote=%{public}d', snapScore, snapVote);
    }
  }

  private onPostUpvote(): void {
    if (this.guarded()) { return; }
    const sScore: number = this.postScore; const sVote: number = this.myPostVote;
    if (this.myPostVote === 1) { this.myPostVote = 0; this.postScore -= 1; }
    else { this.postScore += (this.myPostVote === -1 ? 2 : 1); this.myPostVote = 1; }
    this.rollbackIfFailed(sScore, sVote);
  }
  private onPostDownvote(): void {
    if (this.guarded()) { return; }
    if (this.myPostVote === -1) { this.myPostVote = 0; this.postScore += 1; }
    else { this.postScore -= (this.myPostVote === 1 ? 2 : 1); this.myPostVote = -1; }
  }
  private onBookmark(): void {
    if (this.guarded()) { return; }
    this.bookmarked = !this.bookmarked;
  }

  // ── comment action bar state machine (target = one comment) ──────────
  private mutateComment(id: string, fn: (c: RawComment) => RawComment): void {
    this.comments = this.comments.map((c: RawComment) => c.id === id ? fn(c) : c);
  }
  private onCommentUpvote(c: RawComment): void {
    if (this.guarded()) { return; }
    this.mutateComment(c.id, (x: RawComment): RawComment => {
      const r: RawComment = x;
      if (x.myVote === 1) { r.myVote = 0; r.score = x.score - 1; }
      else { r.score = x.score + (x.myVote === -1 ? 2 : 1); r.myVote = 1; }
      return r;
    });
  }
  private onCommentDownvote(c: RawComment): void {
    if (this.guarded()) { return; }
    this.mutateComment(c.id, (x: RawComment): RawComment => {
      const r: RawComment = x;
      if (x.myVote === -1) { r.myVote = 0; r.score = x.score + 1; }
      else { r.score = x.score - (x.myVote === 1 ? 2 : 1); r.myVote = -1; }
      return r;
    });
  }
  private onCommentBookmark(c: RawComment): void {
    if (this.guarded()) { return; }
    this.mutateComment(c.id, (x: RawComment): RawComment => { const r: RawComment = x; r.saved = !x.saved; return r; });
  }

  // ── collapse / actions-visible (pure local) ──────────────────────────
  private toggleCollapse(id: string): void {
    if (this.collapsedIds.indexOf(id) >= 0) {
      this.collapsedIds = this.collapsedIds.filter((x: string) => x !== id);
    } else {
      this.collapsedIds = this.collapsedIds.concat([id]);
    }
  }
  private toggleActions(id: string): void {
    if (this.actionsHiddenIds.indexOf(id) >= 0) {
      this.actionsHiddenIds = this.actionsHiddenIds.filter((x: string) => x !== id);
    } else {
      this.actionsHiddenIds = this.actionsHiddenIds.concat([id]);
    }
  }
  private expandMore(parentId: string): void {
    const extra: RawComment[] | undefined = this.moreReplies[parentId];
    if (extra !== undefined) { this.comments = this.comments.concat(extra); }
    this.expandedMoreIds = this.expandedMoreIds.concat([parentId]);
  }

  // ── subscribe / sort / navigation ────────────────────────────────────
  private onSubscribe(): void {
    if (this.guarded()) { return; }
    this.subscribed = !this.subscribed;
  }
  private pickSort(s: string): void {
    this.sortBy = s;
    this.sortMenuOpen = false;
  }
  private gotoEditor(parentCommentId: string): void {
    if (this.guarded()) { return; }
    router.pushUrl({
      url: 'pages/CommentEditorPage',
      params: { postId: this.postId, communityId: this.communityId, parentCommentId: parentCommentId }
    });
  }
  private appendComment(parentId: string, body: string): void {
    this.newCommentSeq += 1;
    const nc: RawComment = {
      id: `new${this.newCommentSeq}`, parentId: parentId, author: 'you', body: body,
      score: 1, myVote: 1, saved: false, timeText: 'now', edited: false, editTimeText: '',
      hotRank: 999, createdOrder: 999, controversy: 0, hasMoreChildren: false
    };
    this.comments = this.comments.concat([nc]);
  }

  // ── more-options menu ────────────────────────────────────────────────
  private openMore(target: string): void {
    this.moreTarget = target;
    this.moreMenuOpen = true;
  }
  private moreViewSource(): void {
    if (this.moreTarget === 'post') { this.sourceText = this.postBody; }
    else {
      const found: RawComment | undefined = this.comments.find((c: RawComment) => c.id === this.moreTarget);
      this.sourceText = found !== undefined ? found.body : '';
    }
    this.moreMenuOpen = false;
    this.sourceDialogOpen = true;
  }
  private moreCopyLink(): void { this.moreMenuOpen = false; this.toast('Link copied'); }
  private moreItem(label: string): void { this.moreMenuOpen = false; this.toast(label); }

  // ── UI ───────────────────────────────────────────────────────────────
  @Builder
  private TopBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('←').fontSize(22).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('Back').onClick(() => router.back());

      Column() {
        Text(this.communityName).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1F1F1F')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.sortBy).fontSize(12).fontColor('#666666').margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 });

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⇵').fontSize(18).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('Sort by').onClick(() => { this.sortMenuOpen = true; });

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⋮').fontSize(20).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('More options').onClick(() => this.openMore('post'));
    }
    .width('100%').height(56).padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center).backgroundColor('#FFFFFF');
  }

  @Builder
  private CommunityBanner() {
    Column() {
      Column().width(96).height(96).borderRadius(48).backgroundColor('#1976D2').margin({ top: 16 });
      Text(this.bannerTitle).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1F1F1F').margin({ top: 12 });
      Text(this.bannerUsersText).fontSize(13).fontColor('#666666').margin({ top: 4 });
      Row() {
        Text(this.subscribed ? '✓' : '+').fontSize(14).fontColor('#FFFFFF').margin({ right: 6 });
        Text(this.subscribed ? 'Subscribed' : 'Subscribe').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF');
      }
      .padding({ left: 24, right: 24, top: 10, bottom: 10 }).borderRadius(20)
      .backgroundColor(this.subscribed ? '#43A047' : '#1976D2').margin({ top: 14 })
      .onClick(() => this.onSubscribe());
    }
    .width('100%').alignItems(HorizontalAlign.Center).padding({ bottom: 16 }).backgroundColor('#F6F6F6');
  }

  @Builder
  private PostCard() {
    Column() {
      Row() {
        Column().width(32).height(32).borderRadius(16).backgroundColor('#FF9800');
        Text(this.postAuthor).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#1F1F1F').margin({ left: 8 });
        if (this.featuredLocal) {
          Text('Featured locally').fontSize(11).fontColor('#1976D2').margin({ left: 8 });
        }
        if (this.featuredCommunity) {
          Text('Featured in community').fontSize(11).fontColor('#1976D2').margin({ left: 8 });
        }
        Blank().layoutWeight(1);
        Text(this.postTimeText).fontSize(12).fontColor('#666666');
      }.width('100%').alignItems(VerticalAlign.Center);

      Text(this.postTitle).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1F1F1F').margin({ top: 12 }).width('100%');
      Text(this.postBody).fontSize(14).fontColor('#444444').margin({ top: 10 })
        .maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis });

      Row() {
        Blank().layoutWeight(1);
        Row() {
          Text('▲').fontSize(18).fontColor(this.myPostVote === 1 ? '#FF6600' : '#666666');
          Text(`${this.postScore}`).fontSize(13).fontColor('#1F1F1F').margin({ left: 6 });
        }.padding({ left: 14, right: 14, top: 8, bottom: 8 }).onClick(() => this.onPostUpvote());

        if (this.downvotesEnabled) {
          Text('▼').fontSize(18).fontColor(this.myPostVote === -1 ? '#1976D2' : '#666666')
            .padding(8).onClick(() => this.onPostDownvote());
        }
        Text(this.bookmarked ? '★' : '☆').fontSize(18).fontColor(this.bookmarked ? '#FFC107' : '#666666')
          .padding(8).onClick(() => this.onBookmark());
        Text('⋮').fontSize(18).fontColor('#666666').padding(8).onClick(() => this.openMore('post'));
      }.width('100%').margin({ top: 12 }).alignItems(VerticalAlign.Center);
    }
    .width('100%').padding(16).backgroundColor('#FFFFFF');
  }

  @Builder
  private GoneRow(depth: number) {
    Row() {
      Text('Comment gone').fontSize(14).fontStyle(FontStyle.Italic).fontColor('#999999');
    }
    .width('100%').padding({ left: 16 + depth * 24, right: 16, top: 10, bottom: 10 })
    .border({ width: { left: depth > 0 ? 2 : 0 }, color: { left: '#1976D2' }, style: { left: BorderStyle.Solid } });
  }

  @Builder
  private MoreRepliesRow(node: DisplayNode) {
    Row() {
      Text('Show more replies').fontSize(13).fontColor('#1976D2');
    }
    .width('100%').padding({ left: 16 + node.depth * 24, right: 16, top: 8, bottom: 8 })
    .onClick(() => this.expandMore(node.parentForMore));
  }

  @Builder
  private CommentRow(node: DisplayNode) {
    Column() {
      // header (tap = collapse toggle, long-press = actions toggle)
      Row() {
        Column().width(28).height(28).borderRadius(14).backgroundColor('#FF9800');
        Text(node.comment!.author).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#1F1F1F').margin({ left: 8 });
        if (node.comment!.edited) {
          Text(`✎ ${node.comment!.editTimeText}`).fontSize(11).fontColor('#888888').margin({ left: 8 });
        }
        if (this.collapsedIds.indexOf(node.id) >= 0 && node.descendantCount > 0) {
          Text(`+${node.descendantCount}`).fontSize(12).fontColor('#1976D2').margin({ left: 8 });
        }
        Blank().layoutWeight(1);
        Text(node.comment!.timeText).fontSize(12).fontColor('#888888');
      }
      .width('100%').alignItems(VerticalAlign.Center)
      .onClick(() => this.toggleCollapse(node.id))
      .gesture(LongPressGesture({ repeat: false, duration: 500 })
        .onAction(() => this.toggleActions(node.id)));

      if (this.collapsedIds.indexOf(node.id) < 0) {
        Text(node.comment!.body).fontSize(14).fontColor('#1F1F1F').margin({ top: 6 }).width('100%');

        if (this.actionsHiddenIds.indexOf(node.id) < 0) {
          Row() {
            Text(`${node.comment!.score}`).fontSize(12).fontColor('#1F1F1F').layoutWeight(1);
            Text('▲').fontSize(16).fontColor(node.comment!.myVote === 1 ? '#FF6600' : '#666666')
              .padding(6).onClick(() => this.onCommentUpvote(node.comment!));
            if (this.downvotesEnabled) {
              Text('▼').fontSize(16).fontColor(node.comment!.myVote === -1 ? '#1976D2' : '#666666')
                .padding(6).onClick(() => this.onCommentDownvote(node.comment!));
            }
            Text(node.comment!.saved ? '★' : '☆').fontSize(16)
              .fontColor(node.comment!.saved ? '#FFC107' : '#666666')
              .padding(6).onClick(() => this.onCommentBookmark(node.comment!));
            Text('↩').fontSize(16).fontColor('#666666').padding(6).onClick(() => this.gotoEditor(node.comment!.id));
            Text('⋮').fontSize(16).fontColor('#666666').padding(6).onClick(() => this.openMore(node.comment!.id));
          }.width('100%').margin({ top: 4 }).alignItems(VerticalAlign.Center);
        }
      }
    }
    .width('100%').padding({ left: 16 + node.depth * 24, right: 16, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .border({ width: { left: node.depth > 0 ? 2 : 0 }, color: { left: '#1976D2' }, style: { left: BorderStyle.Solid } });
  }

  @Builder
  private Fab() {
    Column() { Text('+').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF'); }
    .width(56).height(56).borderRadius(28).backgroundColor('#1976D2')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .position({ x: '82%', y: '86%' })
    .onClick(() => this.gotoEditor(''));
  }

  @Builder
  private MenuItem(label: string, onTap: () => void) {
    Text(label).width('100%').fontSize(15).fontColor('#1F1F1F')
      .padding({ left: 24, right: 24, top: 14, bottom: 14 }).onClick(() => onTap());
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.TopBar();
        if (this.guardBannerVisible) {
          Row() {
            Text('You must be logged in to do that').fontSize(13).fontColor('#FFFFFF').layoutWeight(1);
            Text('✕').fontSize(14).fontColor('#FFFFFF').onClick(() => { this.guardBannerVisible = false; });
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 }).backgroundColor('#D32F2F');
        }
        if (this.errorBannerVisible) {
          Row() {
            Text("Couldn't save — reverted").fontSize(13).fontColor('#FFFFFF').layoutWeight(1);
            Text('✕').fontSize(14).fontColor('#FFFFFF').onClick(() => { this.errorBannerVisible = false; });
          }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 }).backgroundColor('#E65100');
        }
        if (this.loading) {
          // 场景一 step 5: loading indicator until the post + comments return.
          Column() {
            LoadingProgress().width(44).height(44).color('#1976D2');
            Text('Loading…').fontSize(13).fontColor('#888888').margin({ top: 10 });
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center);
        } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            ListItem() { this.CommunityBanner(); }
            ListItem() { this.PostCard(); }
            ListItem() { Divider().strokeWidth(0.5).color('#EEEEEE').margin({ left: 16, right: 16 }); }
            ForEach(this.displayList(), (node: DisplayNode) => {
              ListItem() {
                if (node.kind === 'comment') { this.CommentRow(node); }
                else if (node.kind === 'gone') { this.GoneRow(node.depth); }
                else { this.MoreRepliesRow(node); }
              }
            }, (node: DisplayNode) => node.key);
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Auto)
          .divider({ strokeWidth: 0.5, color: '#EEEEEE', startMargin: 16, endMargin: 16 });
        }
        .onRefreshing(() => {
          hilog.info(0x0000, TAG, 'REFRESH triggered sort=%{public}s', this.sortBy);
          this.loadPost(); this.isRefreshing = false;
        })
        .layoutWeight(1).width('100%');
        }
      }
      .width('100%').height('100%').backgroundColor('#FFFFFF');

      this.Fab();

      // sort menu
      if (this.sortMenuOpen) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#33000000').onClick(() => { this.sortMenuOpen = false; });
          Column() {
            Text('Sort comments').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1F1F1F').padding(16);
            ForEach(SORTS, (s: string) => {
              Row() {
                Text(s).fontSize(15).fontColor('#1F1F1F').layoutWeight(1);
                if (this.sortBy === s) { Text('✓').fontSize(15).fontColor('#1976D2'); }
              }.width('100%').padding({ left: 24, right: 24, top: 14, bottom: 14 }).onClick(() => this.pickSort(s));
            }, (s: string) => s);
          }.width(300).backgroundColor('#FFFFFF').borderRadius(12).shadow({ radius: 12, color: '#40000000' });
        }.width('100%').height('100%');
      }

      // more-options menu
      if (this.moreMenuOpen) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#33000000').onClick(() => { this.moreMenuOpen = false; });
          Column() {
            this.MenuItem('View source', () => this.moreViewSource());
            this.MenuItem('Copy link', () => this.moreCopyLink());
            this.MenuItem('Report', () => this.moreItem('Report'));
            this.MenuItem('Block user', () => this.moreItem('Block user'));
            this.MenuItem('View profile', () => this.moreItem('View profile'));
            this.MenuItem(this.moreTarget === 'post' ? 'Hide post' : 'Collapse', () => this.moreItem('Done'));
          }.width(280).backgroundColor('#FFFFFF').borderRadius(12).shadow({ radius: 12, color: '#40000000' });
        }.width('100%').height('100%');
      }

      // view-source read-only dialog
      if (this.sourceDialogOpen) {
        Stack() {
          Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => { this.sourceDialogOpen = false; });
          Column() {
            Text('Source').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1F1F1F').padding({ left: 16, right: 16, top: 16, bottom: 8 });
            Text(this.sourceText).fontSize(13).fontColor('#333333').padding({ left: 16, right: 16, bottom: 12 });
            Row() {
              Text('Close').fontSize(15).fontColor('#1976D2').padding(16).onClick(() => { this.sourceDialogOpen = false; });
            }.justifyContent(FlexAlign.End).width('100%');
          }.width(320).backgroundColor('#FFFFFF').borderRadius(12).shadow({ radius: 12, color: '#40000000' });
        }.width('100%').height('100%');
      }
    }.width('100%').height('100%');
  }
}
