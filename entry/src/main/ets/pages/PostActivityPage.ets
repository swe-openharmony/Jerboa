// ====================================================================
// Page: PostActivityPage
// App: Jerboa
// Android baseline:
//   - D:/OH-Appforge/_doc_screenshots_v2/Jerboa/L1_2_post_detail.png
//   - D:/OH-Appforge/_doc_screenshots_v2/Jerboa/L1_2_post_detail.xml
// Layout contract:
//   - Top bar: back + community name + "Active" + Sort + More
//   - Community header card: avatar circle + community title + "X users / month" + Subscribe button
//   - Post card: author + flags + time + title + body (markdown plain) + score/vote/bookmark/more
//   - Flattened comment list (each comment has `depth`; render indent via padding)
//   - Floating Create-post FAB
// ====================================================================
// NOTE: ArkTS does not support @Component recursion well; we flatten the
// comment tree into a list with `depth` and indent by padding({ left: depth*24 }).
// ====================================================================

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MockDataSource } from '../common/MockDataSource';

const TAG = 'PostActivityPage';

interface FlatComment {
  id: string;
  author: string;
  body: string;
  score: number;
  myVote: number; // -1, 0, +1
  timeText: string;
  depth: number;
}

interface PostInfo {
  communityName: string;
  communityStatus: string;
  bannerTitle: string;
  bannerUsersText: string;
  postAuthor: string;
  postTimeText: string;
  postTitle: string;
  postBody: string;
  postScore: number;
}

interface PostFile {
  post: PostInfo;
  comments: FlatComment[];
}

@Entry
@Component
struct PostActivityPage {
  @State private communityName: string = '';
  @State private communityStatus: string = '';
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

  @State private comments: FlatComment[] = [];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string> | undefined;
    if (params && params.postId) {
      hilog.info(0x0000, TAG, 'load post %{public}s (TODO)', params.postId);
    }
    this.loadPost();
  }

  private async loadPost(): Promise<void> {
    try {
      const data = await MockDataSource.loadJson<PostFile>(this, 'mock_post.json');
      const p: PostInfo = data.post;
      this.communityName = p.communityName;
      this.communityStatus = p.communityStatus;
      this.bannerTitle = p.bannerTitle;
      this.bannerUsersText = p.bannerUsersText;
      this.postAuthor = p.postAuthor;
      this.postTimeText = p.postTimeText;
      this.postTitle = p.postTitle;
      this.postBody = p.postBody;
      this.postScore = p.postScore;
      this.comments = data.comments;
      hilog.info(0x0000, TAG, 'loaded post + %{public}d comments from rawfile', this.comments.length);
    } catch (e) {
      hilog.error(0x0000, TAG, 'load failed: %{public}s', String(e));
      this.comments = [];
    }
  }

  private onBack(): void {
    router.back();
  }

  private onSort(): void {
    hilog.info(0x0000, TAG, 'TODO open sort sheet');
  }

  private onMore(): void {
    hilog.info(0x0000, TAG, 'TODO open more options');
  }

  private onSubscribe(): void {
    this.subscribed = !this.subscribed;
  }

  private onPostUpvote(): void {
    if (this.myPostVote === 1) {
      this.myPostVote = 0;
      this.postScore -= 1;
    } else {
      this.postScore += (this.myPostVote === -1 ? 2 : 1);
      this.myPostVote = 1;
    }
  }

  private onPostDownvote(): void {
    if (this.myPostVote === -1) {
      this.myPostVote = 0;
      this.postScore += 1;
    } else {
      this.postScore -= (this.myPostVote === 1 ? 2 : 1);
      this.myPostVote = -1;
    }
  }

  private onBookmark(): void {
    this.bookmarked = !this.bookmarked;
  }

  private onCommentUpvote(id: string): void {
    hilog.info(0x0000, TAG, 'upvote comment %{public}s', id);
  }

  private onCreatePost(): void {
    hilog.info(0x0000, TAG, 'TODO create post');
  }

  @Builder
  private TopBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('←').fontSize(22).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('Back')
      .onClick(() => this.onBack());

      Column() {
        Text(this.communityName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F1F1F')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.communityStatus)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 2 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 });

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⇵').fontSize(18).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('Sort by')
      .onClick(() => this.onSort());

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('⋮').fontSize(20).fontColor('#1F1F1F');
      }
      .width(40).height(40).backgroundColor(Color.Transparent)
      .accessibilityText('More options')
      .onClick(() => this.onMore());
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFFFFF');
  }

  @Builder
  private CommunityBanner() {
    Column() {
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#1976D2')
        .margin({ top: 16 })
        .onClick(() => console.info('TODO: open community avatar'));
      Text(this.bannerTitle)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F1F1F')
        .margin({ top: 12 })
        .onClick(() => console.info('TODO: open community page'));
      Text(this.bannerUsersText)
        .fontSize(13)
        .fontColor('#666666')
        .margin({ top: 4 })
        .onClick(() => console.info('TODO: show community stats'));
      Row() {
        Text(this.subscribed ? '✓' : '+')
          .fontSize(14)
          .fontColor(this.subscribed ? '#FFFFFF' : '#FFFFFF')
          .margin({ right: 6 });
        Text(this.subscribed ? 'Subscribed' : 'Subscribe')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF');
      }
      .padding({ left: 24, right: 24, top: 10, bottom: 10 })
      .borderRadius(20)
      .backgroundColor(this.subscribed ? '#43A047' : '#1976D2')
      .margin({ top: 14 })
      .onClick(() => this.onSubscribe());
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: 16 })
    .backgroundColor('#F6F6F6');
  }

  @Builder
  private PostCard() {
    Column() {
      Row() {
        Column()
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor('#FF9800')
          .onClick(() => console.info('TODO: open author profile'));
        Text(this.postAuthor)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F1F1F')
          .margin({ left: 8 })
          .onClick(() => console.info('TODO: open author profile (name)'));
        Text('·').fontSize(13).fontColor('#999999').margin({ left: 6, right: 6 });
        Text('⚑').fontSize(12).fontColor('#666666')
          .onClick(() => console.info('TODO: open mod actions flag'));
        Text('·').fontSize(13).fontColor('#999999').margin({ left: 6, right: 6 });
        Text('★').fontSize(12).fontColor('#666666')
          .onClick(() => console.info('TODO: toggle featured/star'));
        Blank().layoutWeight(1);
        Text(this.postTimeText).fontSize(12).fontColor('#666666')
          .onClick(() => console.info('TODO: show post timestamp tooltip'));
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(this.postTitle)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F1F1F')
        .margin({ top: 12 })
        .width('100%')
        .onClick(() => console.info('TODO: expand post title'));

      Text(this.postBody)
        .fontSize(14)
        .fontColor('#444444')
        .margin({ top: 10 })
        .maxLines(6)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => console.info('TODO: expand post body'));

      // Action bar
      Row() {
        Text(`${this.postScore}`)
          .fontSize(14)
          .fontColor('#1F1F1F')
          .layoutWeight(1);

        Row() {
          Text('▲')
            .fontSize(18)
            .fontColor(this.myPostVote === 1 ? '#FF6600' : '#666666');
          Text(`${this.postScore}`)
            .fontSize(13)
            .fontColor('#1F1F1F')
            .margin({ left: 6 });
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .onClick(() => this.onPostUpvote());

        Text('▼')
          .fontSize(18)
          .fontColor(this.myPostVote === -1 ? '#1976D2' : '#666666')
          .padding(8)
          .onClick(() => this.onPostDownvote());

        Text('☆')
          .fontSize(18)
          .fontColor(this.bookmarked ? '#FFC107' : '#666666')
          .padding(8)
          .onClick(() => this.onBookmark());

        Text('⋮')
          .fontSize(18)
          .fontColor('#666666')
          .padding(8)
          .onClick(() => this.onMore());
      }
      .width('100%')
      .margin({ top: 12 })
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF');
  }

  @Builder
  private CommentRow(c: FlatComment) {
    Column() {
      Row() {
        Column()
          .width(28)
          .height(28)
          .borderRadius(14)
          .backgroundColor('#FF9800')
          .onClick(() => console.info(`TODO: open profile ${c.author}`));
        Text(c.author)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F1F1F')
          .margin({ left: 8 })
          .onClick(() => console.info(`TODO: open profile name ${c.author}`));
        Blank().layoutWeight(1);
        Text(c.timeText).fontSize(12).fontColor('#888888')
          .onClick(() => console.info(`TODO: show timestamp ${c.id}`));
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(c.body)
        .fontSize(14)
        .fontColor('#1F1F1F')
        .margin({ top: 6 })
        .width('100%')
        .onClick(() => console.info(`TODO: toggle comment expand ${c.id}`));

      Row() {
        Text(`${c.score}`)
          .fontSize(12)
          .fontColor('#1F1F1F')
          .layoutWeight(1);
        Text('▲')
          .fontSize(16)
          .fontColor(c.myVote === 1 ? '#FF6600' : '#666666')
          .padding(6)
          .onClick(() => this.onCommentUpvote(c.id));
        Text('▼')
          .fontSize(16)
          .fontColor(c.myVote === -1 ? '#1976D2' : '#666666')
          .padding(6)
          .onClick(() => console.info(`TODO: downvote ${c.id}`));
        Text('☆')
          .fontSize(16)
          .fontColor('#666666')
          .padding(6)
          .onClick(() => console.info(`TODO: bookmark comment ${c.id}`));
        Text('↩')
          .fontSize(16)
          .fontColor('#666666')
          .padding(6)
          .onClick(() => console.info(`TODO: reply to ${c.id}`));
        Text('⋮')
          .fontSize(16)
          .fontColor('#666666')
          .padding(6)
          .onClick(() => console.info(`TODO: more actions ${c.id}`));
      }
      .width('100%')
      .margin({ top: 4 })
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .padding({ left: 16 + c.depth * 24, right: 16, top: 10, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .border({
      width: { left: c.depth > 0 ? 2 : 0 },
      color: { left: '#1976D2' },
      style: { left: BorderStyle.Solid }
    })
    .onClick(() => console.info(`TODO: open comment ${c.id}`));
  }

  @Builder
  private Fab() {
    Column() {
      Text('+').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FFFFFF');
    }
    .width(56)
    .height(56)
    .borderRadius(28)
    .backgroundColor('#1976D2')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .position({ x: '82%', y: '88%' })
    .onClick(() => this.onCreatePost());
  }

  build() {
    Stack() {
      Column() {
        this.TopBar();
        List() {
          ListItem() {
            this.CommunityBanner();
          }
          ListItem() {
            this.PostCard();
          }
          ListItem() {
            Divider().strokeWidth(0.5).color('#EEEEEE').margin({ left: 16, right: 16 });
          }
          ForEach(this.comments, (c: FlatComment) => {
            ListItem() {
              this.CommentRow(c);
            }
          }, (c: FlatComment) => c.id);
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .divider({ strokeWidth: 0.5, color: '#EEEEEE', startMargin: 16, endMargin: 16 });
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF');

      this.Fab();
    }
    .width('100%')
    .height('100%');
  }
}
