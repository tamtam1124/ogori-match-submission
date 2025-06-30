import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {
  VertexAI,
  GenerativeModel,
  HarmCategory,
  HarmBlockThreshold,
} from "@google-cloud/vertexai";

admin.initializeApp();

// 統一されたVertex AIサービス
class UnifiedVertexAIService {
  private readonly client: VertexAI;
  private readonly model: GenerativeModel;

  constructor() {
    this.client = new VertexAI({
      project: process.env.GOOGLE_CLOUD_PROJECT || "engineeringu",
      location: "us-central1",
    });

    this.model = this.client.getGenerativeModel({
      model: "gemini-1.5-pro",
      safetySettings: [
        {
          category: HarmCategory.HARM_CATEGORY_HARASSMENT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_HATE_SPEECH,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
        {
          category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
          threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE,
        },
      ],
      generationConfig: {
        maxOutputTokens: 512,
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
      },
    });
  }

  // 🔧 修正: Vertex AI SDK v1.9.0に対応
  async generateText(prompt: string): Promise<string> {
    const result = await this.model.generateContent({
      contents: [{role: "user", parts: [{text: prompt}]}],
    });

    // 正しいレスポンス取得方法
    const candidates = result.response.candidates;
    if (!candidates || candidates.length === 0) {
      throw new Error("No content was generated.");
    }

    const content = candidates[0].content;
    if (!content || !content.parts || content.parts.length === 0) {
      throw new Error("No text content was generated.");
    }

    return content.parts[0].text || "";
  }
}

// hello関数 (既存)
export const hello = functions.https.onCall((request) => {
  return {message: "Hello World!"};
});

// AIミッション生成関数 (修正版)
export const generateMission = functions.https.onCall({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 120,
  minInstances: 0,
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "ユーザー認証が必要です。");
  }

  // ✅ 認証ユーザーIDを自動取得
  const currentUserId = request.auth.uid;

  // ✅ パートナーIDは任意パラメータまたは自動選択
  const {partnerUserId} = request.data;

  try {
    const db = admin.firestore();

    // ✅ 現在のユーザー情報を取得
    const currentUserDoc = await db.collection("users").doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError("not-found", "現在のユーザーが見つかりません。");
    }

    let finalPartnerUserId = partnerUserId;

    // ✅ パートナーが指定されていない場合は自動選択
    if (!finalPartnerUserId) {
      const otherUsersSnapshot = await db
        .collection("users")
        .where(admin.firestore.FieldPath.documentId(), "!=", currentUserId)
        .limit(1)
        .get();

      if (otherUsersSnapshot.empty) {
        throw new functions.https.HttpsError("not-found", "パートナーユーザーが見つかりません。");
      }

      finalPartnerUserId = otherUsersSnapshot.docs[0].id;
    }

    // ✅ パートナーユーザー情報を取得
    const partnerUserDoc = await db.collection("users").doc(finalPartnerUserId).get();
    if (!partnerUserDoc.exists) {
      throw new functions.https.HttpsError("not-found", "パートナーユーザーが見つかりません。");
    }

    // ✅ 2人のプロフィールを構築
    const currentUserData = currentUserDoc.data()!;
    const partnerUserData = partnerUserDoc.data()!;

    const userProfiles = [
      {
        userId: currentUserId,
        name: currentUserData.displayName || "名前未設定",
        department: currentUserData.location || "部署未設定",
        email: currentUserData.email || "",
      },
      {
        userId: finalPartnerUserId,
        name: partnerUserData.displayName || "名前未設定",
        department: partnerUserData.location || "部署未設定",
        email: partnerUserData.email || "",
      }
    ];

    // ✅ 既存のVertexAI処理をそのまま使用
    const aiService = new UnifiedVertexAIService();
    const prompt = buildMissionPrompt(userProfiles);

    console.log("🤖 Vertex AI でミッション生成開始");
    const missionText = await aiService.generateText(prompt);
    console.log("✅ Vertex AI ミッション生成成功");
    console.log("📄 生成されたテキスト:", missionText);

    return {
      mission: {
        id: `ai-mission-${Date.now()}`,
        text: missionText,
        participants: [currentUserId, finalPartnerUserId],
      },
      metadata: {
        modelUsed: "vertex-ai-gemini-1.5-pro",
        generatedAt: new Date().toISOString(),
        currentUser: currentUserId,
        partnerUser: finalPartnerUserId,
      },
    };
  } catch (error) {
    console.error("❌ Mission generation error:", error);

    // より魅力的なフォールバック質問に変更
    const fallbackMissions = [
      "もし1日だけ別の部署で働けるとしたら、どの部署を選びますか？その理由も教えてください。",
      "コーヒーと紅茶、どちらが好きですか？その理由と、おすすめの飲み方があれば教えてください。",
      "最近「これは良いアイデアだ！」と思ったことはありますか？どんなことか教えてください。"
    ];

    const randomFallback = fallbackMissions[Math.floor(Math.random() * fallbackMissions.length)];

    return {
      mission: {
        id: `fallback-${Date.now()}`,
        text: randomFallback,
      },
      metadata: {
        isFallback: true,
        reason: "AI_GENERATION_FAILED",
      },
    };
  }
});

// ミッション生成プロンプト
function buildMissionPrompt(userProfiles: any[]): string {

  const user1 = userProfiles[0];
  const user2 = userProfiles[1];

  // 部署が違う場合の特別指示
  const departmentHint = user1.department !== user2.department
    ? `\n【特別指示】2人は異なる部署（${user1.department} と ${user2.department}）なので、お互いの仕事や専門性を理解できるような質問も考慮してください。`
    : "";

  const questionTypes = [
    "「もし〜なら？」形式の想像質問",
    "「AとB、どちらが好き？」形式の選択質問",
    "「一番〜なことは？」形式の体験質問",
    "「周りから〜と言われる？」形式の他者視点質問",
    "「こだわりの〜は？」形式の価値観質問"
  ];

  const randomType = questionTypes[Math.floor(Math.random() * questionTypes.length)];

  return `あなたは、数々の企業のチームビルディングを成功させてきた、伝説のコミュニケーションデザイナーです。あなたの使命は、参加者のプロフィールを深く洞察し、2人の心理的な距離を縮めるための、ユニークでポジティブな会話のきっかけをデザインすることです。

  【思考プロセス】
1. まず、参加者2名のプロフィール（名前、部署）から、2人の関係性を推測してください。（例：同じ部署で働く親しい同僚、異なる部署の先輩と後輩など）
2. 次に、その関係性に最適な質問のトーン（例：気軽なアイスブレイク、仕事の価値観に少し触れるもの、意外な一面を引き出すもの）を判断してください。
3. 最後に、上記1と2の分析を踏まえ、最も2人の会話が盛り上がる質問を1つだけ生成してください。

参加者：
- ${user1.name}（${user1.department}）
- ${user2.name}（${user2.department}）${departmentHint}

【今回は「${randomType}」で、2人が楽しめる会話ミッションを提案してください。

【重要】以下の形式で作成してください：
「【お互いに答えてみましょう】
質問：[質問内容]

ステップ1：${user1.name}さんが${user2.name}さんに質問して、回答を入力してください
ステップ2：${user2.name}さんが${user1.name}さんに同じ質問をして、回答を入力してください」

【必須条件】
- 2-3分で回答できる内容
- テキストで回答可能
- 誰でも不快にならない内容
- ポジティブで楽しい内容
- 回答することで、お互いの意外な一面や価値観が垣間見えること。

【良いミッションの例】
- 「もし魔法が一つ使えるとしたら、どんな能力が欲しいですか？その理由も教えてください！」
- 「社会人になってから一番『成長したな』と感じた瞬間はどんな時ですか？」
- 「最近ハマっている"もの"や"こと"があれば教えてください！」

【悪いミッションの例】
- 「会社の周辺にある新しいお店を探検し、写真を撮って共有しよう。」
- 「お互いのデスク周りで一番お気に入りのアイテムを見せ合おう。」
- 「今日のランチの写真を送ってください。」

【禁止事項】
- 物理的な行動（写真撮影、移動など）を要求すること。
- 政治・宗教・家族・収入・身体的特徴に関する質問は厳禁

回答は質問文のみを簡潔に返してください。`;
}

// ⭐ 修正版: AIプロフィール生成関数
export const generateAiProfile = functions.https.onCall({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 120,
  minInstances: 0,
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "ユーザー認証が必要です。");
  }

  const userId = request.auth.uid;
  const forceRegenerate = request.data?.forceRegenerate || false; // ✅ 追加

  try {
    const db = admin.firestore();

    // ✅ 強制再生成でない場合は既存データをチェック
    if (!forceRegenerate) {
      const existingProfile = await db.collection("aiProfiles").doc(userId).get();
      if (existingProfile.exists) {
        const existingData = existingProfile.data()!;

        console.log("📋 既存のAIプロフィールを返却");
        return {
          success: true,
          profile: {
            comprehensivePersonality: existingData.comprehensivePersonality,
            futurePreview: existingData.futurePreview,
            keywordsList: existingData.keywordsList,
            generatedAt: existingData.updatedAt.toDate().toISOString(),
            isExisting: true,
          },
          metadata: {
            isRegenerated: false,
            existingProfile: true,
          },
        };
      }
    }

    // ユーザーの基本情報を取得
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "ユーザーが見つかりません。");
    }

    const userData = userDoc.data()!;

    // ✅ フィードバックデータを最新で取得（件数を増やして精度向上）
    const feedbackSnapshot = await db
      .collection("mission_results")
      .where("userId", "==", userId)
      .orderBy("submittedAt", "desc")  // 最新順
      .limit(20)  // 件数を増加
      .get();

    console.log(`📝 フィードバック検索: collection="mission_results", userId="${userId}"`);
    console.log(`✅ 取得したフィードバック数: ${feedbackSnapshot.docs.length}`);

    const feedbacks = feedbackSnapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        feedbackText: data.feedbackText || '',
        fromUserId: data.fromUserId || data.submitterId || '',
        targetUserId: data.targetUserId || data.userId || '',
        submittedAt: data.submittedAt,
        missionQuestion: data.missionQuestion || 'ミッション内容不明',
        fromUserName: data.fromUserName || data.submitterName || '匿名',
        ...data,
      };
    });

    // Vertex AI でプロフィール生成
    const aiService = new UnifiedVertexAIService();
    const prompt = buildProfilePrompt(userData, feedbacks);

    console.log(`🤖 Vertex AI でプロフィール${forceRegenerate ? '再' : ''}生成開始`);
    const profileText = await aiService.generateText(prompt);
    console.log("✅ Vertex AI プロフィール生成成功");

    // 3項目構造化されたテキストを解析
    const parsedProfile = parseProfileResponse(profileText);

    // ✅ Firestoreに構造化データで保存（更新日時も記録)
    const existingDoc = await db.collection("aiProfiles").doc(userId).get();

    await db.collection("aiProfiles").doc(userId).set({
      userId: userId,
      comprehensivePersonality: parsedProfile.comprehensivePersonality,
      futurePreview: parsedProfile.futurePreview,
      keywordsList: parsedProfile.keywords,
      createdAt: existingDoc.exists ?
        existingDoc.data()?.createdAt : admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
      feedbackCount: feedbacks.length,
      lastRegeneratedAt: forceRegenerate ? admin.firestore.Timestamp.now() : null,
    }, {merge: true});

    // Flutterに構造化レスポンスを返す
    return {
      success: true,
      profile: {
        comprehensivePersonality: parsedProfile.comprehensivePersonality,
        futurePreview: parsedProfile.futurePreview,
        keywordsList: parsedProfile.keywords,
        generatedAt: new Date().toISOString(),
        feedbackCount: feedbacks.length,
        isRegenerated: forceRegenerate,
      },
      metadata: {
        modelUsed: "vertex-ai-gemini-1.5-pro",
        processingTime: Date.now(),
        hasStructuredOutput: true,
        isRegenerated: forceRegenerate,
      },
    };
  } catch (error) {
    console.error("❌ Profile generation error:", error);

    const errorMessage = error instanceof Error ? error.message : String(error);

    return {
      success: false,
      profile: {
        text: "プロフィールを生成中です。しばらくお待ちください。",
        generatedAt: new Date().toISOString(),
        feedbackCount: 0,
      },
      metadata: {
        isFallback: true,
        reason: "AI_GENERATION_FAILED",
        error: errorMessage,
      },
    };
  }
});

// ⭐ 修正版：3項目構造化出力プロンプト
function buildProfilePrompt(userData: any, feedbacks: any[]): string {
  const feedbackTexts = feedbacks
    .map((feedback, index) => `
${index + 1}. ${feedback.feedbackText || "詳細なフィードバックなし"}
  - 評価者: ${feedback.fromUserName || "匿名"}
  - 日時: ${feedback.createdAt?.toDate?.()?.toLocaleDateString() || "不明"}`)
    .join("");

  return `# 命令書

あなたは、与えられた断片的な情報から本質を見抜く、優れたプロファイラー兼編集者です。
これから提供する、ある人物に関する一連のフィードバックデータを深く分析し、表面的な事実の羅列ではなく、その人の「人間性」「価値観」「性格」が立体的に浮かび上がるような、洞察に満ちた人物紹介を作成してください。

## ユーザー基本情報
- 名前: ${userData.displayName || "未設定"}
- 部署: ${userData.location || "未設定"}
- メール: ${userData.email || "未設定"}

## 入力データ（受け取ったフィードバック: ${feedbacks.length}件）
---
${feedbackTexts || "現在フィードバックはありません"}
---

## 実行すべき分析タスク
以下の思考プロセスを経て、最終的な出力を作成してください。

1. **関連性の分析:**
   フィードバック内容と基本情報の間に、どのような関連性や一貫性が見いだせるか考察してください。

2. **深層心理の推察:**
   特に印象的なフィードバックや、価値観が表れている評価に着目し、その言葉の裏にある、本人が大切にしているであろう信念や、物事を判断する上での軸について推察してください。

3. **多面性の抽出:**
   フィードバックの中に、一見すると矛盾している、あるいは対照的に見える組み合わせがあれば、その「ギャップ」や「多面性」を、その人の魅力や人間的な深みとして解釈し、説明してください。

4. **情報の統合:**
   上記1〜3の分析結果をすべて統合し、この人物がどのような人間であるかを、一貫したストーリーとして再構築してください。

## 出力形式
必ず以下の3つの項目を明確に分けて出力してください。各項目のラベルも含めて記述してください。

### 【総合的な人物像】
分析タスクで得られた洞察を盛り込んだ、総合的な人物像を2-3文で記述してください。

### 【ヨコク】
「ヨコク」とは、単なる未来予測ではなく、「こうありたい」と自ら描く未来像であり、挑戦や意志の表明です。
フィードバックを分析し、その人らしい「ヨコク」を提案してください。
一文で、キャッチコピーのように簡潔かつ力強く。全体をポジティブでワクワクするトーンにしてください。
「〜します！？」のように、最後は“！？”で終わる表現にしてください。

### 【キーワード】
この人物を象徴する5つのキーワードを以下の形式で記述してください：
#キーワード1 #キーワード2 #キーワード3 #キーワード4 #キーワード5

## 出力例

### 【総合的な人物像】
チームの連携を大切にし、常に前向きな姿勢で業務に取り組む方です。細やかな気配りと丁寧なコミュニケーションで、周囲から信頼を得ており、多様な視点を持ちながらも一貫した価値観で判断する魅力的な人物です。

### 【ヨコク】
前向きな挑戦で、みんなを笑顔にする未来を創ります！？

### 【キーワード】
#チームワーク #コミュニケーション力 #成長志向 #信頼性 #柔軟性

上記の形式に従って、フィードバック内容を参考に具体的で魅力的なプロフィールを生成してください。`;
}

// ⭐ 修正版：es2017対応
function parseProfileResponse(responseText: string): {
  comprehensivePersonality: string;
  futurePreview: string;
  keywords: string[];
} {
  try {
    // 【総合的な人物像】セクションを抽出
    const personalityMatch = responseText.match(/【総合的な人物像】[\s\S]*?\n([\s\S]*?)(?=\n### 【|$)/);
    const personality = personalityMatch?.[1]?.trim() || "情報を分析中です...";

    // 【ヨコク】セクションを抽出 ← ここを修正
    const futureMatch = responseText.match(/【ヨコク】[\s\S]*?\n([\s\S]*?)(?=\n### 【|$)/);
    const future = futureMatch?.[1]?.trim() || "ヨコクを分析中です...";

    // 【キーワード】セクションを抽出
    const keywordsMatch = responseText.match(/【キーワード】[\s\S]*?\n(.*?)(?=\n|$)/);
    const keywordsText = keywordsMatch?.[1]?.trim() || "";

    // キーワードを配列に変換（#記号を除去）
    const keywords = keywordsText
      .split(/\s+/)
      .filter(word => word.startsWith('#'))
      .map(word => word.substring(1))
      .filter(word => word.length > 0);

    // デフォルトキーワードを設定（空の場合）
    const finalKeywords = keywords.length > 0 ? keywords : ['分析中', '成長志向', '協調性', '信頼性', '柔軟性'];

    return {
      comprehensivePersonality: personality,
      futurePreview: future,
      keywords: finalKeywords,
    };
  } catch (error) {
    console.error("❌ Profile parsing error:", error);

    // フォールバック値を返す
    return {
      comprehensivePersonality: "プロフィールを分析しています。しばらくお待ちください。",
      futurePreview: "ヨコクを分析しています。しばらくお待ちください。",
      keywords: ['分析中', '成長志向', '協調性', '信頼性', '柔軟性'],
    };
  }
}

// ✨ 新規追加: マッチング処理関数
export const processMatching = functions.https.onCall({
  region: "us-central1",
  memory: "1GiB",
  timeoutSeconds: 60,
  minInstances: 0,
  maxInstances: 10,
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "ユーザー認証が必要です。");
  }

  const currentUserId = request.auth.uid;

  try {
    const db = admin.firestore();

    console.log(`🎯 マッチング処理開始 - User: ${currentUserId}`);

    // Step 1: 既存のキューエントリーを削除
    const existingQueue = await db
      .collection('matching_queue')
      .where('userId', '==', currentUserId)
      .where('status', '==', 'waiting')
      .get();

    for (const doc of existingQueue.docs) {
      await doc.ref.delete();
      console.log(`🗑️ 既存キューエントリー削除: ${doc.id}`);
    }

    // Step 2: 待機中の他のユーザーを検索
    const waitingUsers = await db
      .collection('matching_queue')
      .where('status', '==', 'waiting')
      .orderBy('createdAt')
      .limit(10)
      .get();

    console.log(`📊 待機中ユーザー数: ${waitingUsers.docs.length}`);

    // 自分以外の待機ユーザーを探す
    const availableUsers = waitingUsers.docs.filter(doc =>
      doc.data().userId !== currentUserId
    );

    if (availableUsers.length > 0) {
      // Step 3: マッチング成立
      const partnerQueueDoc = availableUsers[0];
      const partnerId = partnerQueueDoc.data().userId;

      console.log(`🤝 マッチング成立: ${currentUserId} <-> ${partnerId}`);

      // 相手のプロフィールを取得
      const partnerProfile = await db
        .collection('users')
        .doc(partnerId)
        .get();

      if (!partnerProfile.exists) {
        throw new functions.https.HttpsError("not-found", "パートナーのプロフィールが見つかりません");
      }

      // 両方のキューステータスを更新
      const batch = db.batch();

      // 相手のキューを'matched'に更新
      batch.update(partnerQueueDoc.ref, {
        status: 'matched',
        partnerId: currentUserId,
        matchedAt: admin.firestore.Timestamp.now(),
      });

      // マッチング記録を作成
      const matchRef = db.collection('matches').doc();
      batch.set(matchRef, {
        participants: [currentUserId, partnerId],
        status: 'success',
        createdAt: admin.firestore.Timestamp.now(),
        updatedAt: admin.firestore.Timestamp.now(),
      });

      await batch.commit();

      console.log(`✅ マッチング処理完了`);

      return {
        success: true,
        matched: true,
        partner: {
          uid: partnerId,
          displayName: partnerProfile.data()?.displayName || "匿名ユーザー",
          location: partnerProfile.data()?.location || "",
          email: partnerProfile.data()?.email || "",
          profileImageUrl: partnerProfile.data()?.profileImageUrl || null,
        },
        matchId: matchRef.id,
      };

    } else {
      // Step 4: 待機キューに追加
      const queueRef = await db.collection('matching_queue').add({
        userId: currentUserId,
        status: 'waiting',
        createdAt: admin.firestore.Timestamp.now(),
        interests: [],
      });

      console.log(`⏳ キューに追加: ${queueRef.id}`);

      return {
        success: true,
        matched: false,
        queueId: queueRef.id,
        waitingCount: waitingUsers.docs.length + 1,
      };
    }

  } catch (error) {
    console.error("❌ マッチング処理エラー:", error);

    throw new functions.https.HttpsError(
      "internal",
      "マッチング処理でエラーが発生しました",
      { error: error instanceof Error ? error.message : String(error) }
    );
  }
});

// ✨ 新規追加: マッチングキャンセル関数
export const cancelMatching = functions.https.onCall({
  region: "us-central1",
  memory: "512MiB",
  timeoutSeconds: 30,
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "ユーザー認証が必要です。");
  }

  const currentUserId = request.auth.uid;
  const { queueId } = request.data;

  try {
    const db = admin.firestore();

    if (queueId) {
      // 特定のキューエントリーをキャンセル
      await db.collection('matching_queue').doc(queueId).update({
        status: 'cancelled',
        cancelledAt: admin.firestore.Timestamp.now(),
      });
    } else {
      // ユーザーの全ての待機キューをキャンセル
      const userQueues = await db
        .collection('matching_queue')
        .where('userId', '==', currentUserId)
        .where('status', '==', 'waiting')
        .get();

      const batch = db.batch();
      userQueues.docs.forEach(doc => {
        batch.update(doc.ref, {
          status: 'cancelled',
          cancelledAt: admin.firestore.Timestamp.now(),
        });
      });
      await batch.commit();
    }

    console.log(`🚪 マッチングキャンセル完了: ${currentUserId}`);

    return { success: true };

  } catch (error) {
    console.error("❌ マッチングキャンセルエラー:", error);
    throw new functions.https.HttpsError("internal", "キャンセル処理でエラーが発生しました");
  }
});
