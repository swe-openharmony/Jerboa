// Page: Index

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MockDataSource } from '../common/MockDataSource';

const TAG = 'JerboaIndex';

interface Post {
  id: string;
  community: string;
  author: string;
  age: string;
  title: string;
  body: string;
  hasThumb: boolean;
  comments: number;
  upvotes: number;
  downvotes: number;
}

interface HomeFile { posts: Post[]; }

interface NavTab { id: string; label: string; glyph: string; }

@Entry
@Component
struct Index {
  @State private posts: Post[] = [];
  @State private currentTab: string = 'home';

  private tabs: NavTab[] = [
    { id: 'home',    label: 'Home',    glyph: '🏠' },
    { id: 'search',  label: 'Search',  glyph: '🔍' },
    { id: 'inbox',   label: 'Inbox',   glyph: '📧' },
    { id: 'saved',   label: 'Saved',   glyph: '🔖' },
    { id: 'profile', label: 'Profile', glyph: '👤' },
  ];

  aboutToAppear(): void {
    hilog.info(0x0000, TAG, 'Jerboa L0 home mounted');
    this.loadHome();
  }

  private async loadHome(): Promise<void> {
    try {
      const data = await MockDataSource.loadJson<HomeFile>(this, 'mock_home.json');
      this.posts = data.posts;
    } catch (e) {
      hilog.error(0x0000, TAG, 'load failed: %{public}s', String(e));
      this.posts = [];
    }
  }

  private openPost(post: Post): void {
    hilog.info(0x0000, TAG, 'post tap → PostActivityPage id=%{public}s', post.id);
    router.pushUrl({ url: 'pages/PostActivityPage', params: { postId: post.id, title: post.title } });
  }

  private openComments(post: Post): void {
    hilog.info(0x0000, TAG, 'comments tap → PostActivityPage id=%{public}s', post.id);
    router.pushUrl({ url: 'pages/PostActivityPage', params: { postId: post.id, title: post.title } });
  }

  private onUpvote(post: Post): void {
    console.info(`TODO: upvote ${post.id}`);
  }

  private onDownvote(post: Post): void {
    console.info(`TODO: downvote ${post.id}`);
  }

  private onSave(post: Post): void {
    console.info(`TODO: save ${post.id}`);
  }

  private onMore(post: Post): void {
    console.info(`TODO: more ${post.id}`);
  }

  private onCommunity(post: Post): void {
    console.info(`TODO: community ${post.community}`);
  }

  private onAuthor(post: Post): void {
    console.info(`TODO: author ${post.author}`);
  }

  private onThumb(post: Post): void {
    hilog.info(0x0000, TAG, 'thumb tap → PostActivityPage id=%{public}s', post.id);
    router.pushUrl({ url: 'pages/PostActivityPage', params: { postId: post.id, title: post.title } });
  }

  private onTabTap(tab: NavTab): void {
    this.currentTab = tab.id;
    console.info(`TODO: tab ${tab.id}`);
  }

  @Builder
  private TopBar() {
    Row() {
      Text('≡').fontSize(22).fontColor('#1F1F1F').width(40).height(48).textAlign(TextAlign.Center)
        .onClick(() => console.info('TODO: drawer'));
      Column() {
        Text('Local').fontSize(15).fontColor('#1F1F1F');
        Text('Active').fontSize(12).fontColor('#666666');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 4 });
      Text('⊞').fontSize(20).fontColor('#1F1F1F').width(44).height(48).textAlign(TextAlign.Center)
        .onClick(() => console.info('TODO: scope'));
      Text('⤓').fontSize(20).fontColor('#1F1F1F').width(44).height(48).textAlign(TextAlign.Center)
        .onClick(() => console.info('TODO: sort'));
      Text('⋮').fontSize(22).fontColor('#1F1F1F').width(40).height(48).textAlign(TextAlign.Center)
        .onClick(() => console.info('TODO: overflow'));
    }
    .width('100%').height(56)
    .alignItems(VerticalAlign.Center).backgroundColor('#FFFFFF');
  }

  @Builder
  private PostRow(post: Post) {
    Column() {
      // Meta row — community + author each tappable (Android parity)
      Row() {
        Text('🟡').fontSize(11).margin({ right: 6 });
        Text(post.community).fontSize(12).fontColor('#1F1F1F').fontWeight(FontWeight.Medium)
          .onClick(() => this.onCommunity(post));
        Text(' by ').fontSize(12).fontColor('#777777');
        Text(post.author).fontSize(12).fontColor('#1F1F1F')
          .onClick(() => this.onAuthor(post));
        Blank().layoutWeight(1);
        Text(post.age).fontSize(11).fontColor('#777777');
      }
      .width('100%').padding({ left: 12, right: 12, top: 10 })
      .alignItems(VerticalAlign.Center);

      // Title
      Text(post.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1F1F1F')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 });

      // Body + thumbnail row — thumbnail tappable
      Row() {
        Text(post.body).fontSize(13).fontColor('#333333').layoutWeight(1);
        if (post.hasThumb) {
          Column().width(64).height(56).backgroundColor('#E5E5E5').borderRadius(6)
            .margin({ left: 8 })
            .onClick(() => this.onThumb(post));
        }
      }
      .width('100%').padding({ left: 12, right: 12, bottom: 8 })
      .alignItems(VerticalAlign.Top);

      // Action row — each glyph cluster individually tappable
      Row() {
        Row() {
          Text('💬').fontSize(13).margin({ right: 4 });
          Text(`${post.comments}`).fontSize(12).fontColor('#444444');
        }
        .padding({ left: 4, right: 8, top: 4, bottom: 4 })
        .onClick(() => this.openComments(post));

        Blank().layoutWeight(1);

        Row() {
          Text('↑').fontSize(13).fontColor('#444444').margin({ right: 4 });
          Text(`${post.upvotes}`).fontSize(12).fontColor('#444444');
        }
        .padding({ left: 4, right: 8, top: 4, bottom: 4 })
        .onClick(() => this.onUpvote(post));

        Row() {
          Text('↓').fontSize(13).fontColor('#444444').margin({ right: 4 });
          Text(`${post.downvotes}`).fontSize(12).fontColor('#444444');
        }
        .padding({ left: 4, right: 8, top: 4, bottom: 4 })
        .onClick(() => this.onDownvote(post));

        Text('🔖').fontSize(13).padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => this.onSave(post));
        Text('⋮').fontSize(15).fontColor('#444444')
          .padding({ left: 8, right: 4, top: 4, bottom: 4 })
          .onClick(() => this.onMore(post));
      }
      .width('100%').padding({ left: 12, right: 12, bottom: 10 })
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .border({ width: { bottom: 0.5 }, color: '#E0E0E0' })
    .onClick(() => this.openPost(post));
  }

  @Builder
  private BottomNav() {
    Row() {
      ForEach(this.tabs, (tab: NavTab) => {
        Column() {
          Text(tab.glyph).fontSize(18)
            .fontColor(this.currentTab === tab.id ? '#1E88E5' : '#555555');
          Text(tab.label).fontSize(11)
            .fontColor(this.currentTab === tab.id ? '#1E88E5' : '#555555')
            .margin({ top: 2 });
        }
        .layoutWeight(1).height(56).justifyContent(FlexAlign.Center)
        .onClick(() => this.onTabTap(tab));
      }, (tab: NavTab) => tab.id);
    }
    .width('100%').height(60).backgroundColor('#FFFFFF');
  }

  build() {
    Column() {
      this.TopBar();
      List() {
        ForEach(this.posts, (p: Post) => {
          ListItem() { this.PostRow(p); }
        }, (p: Post) => p.id);
      }
      .layoutWeight(1).width('100%');
      this.BottomNav();
    }
    .width('100%').height('100%').backgroundColor('#FFFFFF');
  }
}
