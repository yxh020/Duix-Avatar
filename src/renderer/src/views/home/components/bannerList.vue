<template>
  <div class="banner-content-box">
    <!-- lite 模式只保留批量入口；集成完整三服务后改 v-if="true" 可恢复"短视频制作"单任务卡 -->
    <div v-if="false" class="banner-left" @click="action.handleCreateVideo">
      <div class="left-text">
        <div class="title-box">
          <div class="h1"> {{$t('common.banner0.title') }}</div>
          <div class="text">{{$t('common.banner0.subTitle') }}</div>
        </div>
      </div>
      <div class="right-img">
        <div class="text" :style="locale === 'en' ?  'font-size: 13px;' : ''">{{$t('common.banner0.buttonText') }}</div>
      </div>
    </div>
    <div class="banner-right banner-right--solo">
      <div class="title-box" :style="locale === 'zh' ? '' : 'padding: 12px 0px 0px 32px;'">
        <div class="h1">{{$t('common.banner1.buttonText') }}</div>
        <div class="text" :style="locale === 'zh' ? '' : ' width: 60%;'">{{$t('common.banner1.subTitle') }}</div>
        <div class="link" @click="action.handleQuickCreateModel">
          <div class="link-text" >批量合成</div>
          <img src="../../../assets/images/home/go.svg" />
        </div>
      </div>
      <img class="banner-hero" src="../../../assets/images/home/hero.jpg" alt="hero" />
    </div>
  </div>
</template>
<script setup>
import { createModel } from "@renderer/components/model-create";
import { useRouter } from "vue-router";
import { useI18n } from 'vue-i18n'
const { locale } = useI18n()
const router = useRouter();
const emit = defineEmits(["SubmitOK"]);
const action = {
  async handleCreateVideo() {
    router.push("/video/edit");
  },
  async handleCreateModel() {
    const { isSubmitOK } = await createModel();
    if (isSubmitOK) {
      emit("submitOK");
    }
  },
  async handleQuickCreateModel() {
    router.push("/model/quick-create");
  },
};
</script>
<style lang="less" scoped>
.banner-content-box {
  display: flex;
  width: 100%;
  margin-bottom: 18px;
  justify-content: center;
  gap: 16px;

  .banner-left {
    width: 58%;
    border-radius: 8px;
    display: flex;
    height: 160px;
    cursor: pointer;
    background-image: url("@renderer/assets/images/home/banner01.svg");
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    cursor: pointer;

    .left-text {
      flex: 0.95;

      .title-box {
        padding: 32px 0px 0px 32px;

        .h1 {
          font-family: Alimama FangYuanTi VF-Bold, Alimama FangYuanTi VF-Bold;
          font-weight: normal;
          font-size: 32px;

          color: #ffffff;
          line-height: 48px;
          letter-spacing: 4px;
          font-style: normal;
        }

        .text {
          font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
          font-weight: 400;
          font-size: 12px;
          color: rgba(255, 255, 255, 0.8);
          line-height: 20px;
          letter-spacing: 2px;
          font-style: normal;
          margin-top: 4px;
        }
      }
    }

    .right-img {
      background-image: url("@renderer/assets/images/home/banner01_right.svg");
      background-size: 100% 100%;
      background-repeat: no-repeat;
      width: 266px;
      margin-top: 25px;
      height: 114px;
      cursor: pointer;
      background-position: center;

      .text {
        font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
        font-weight: bold;
        font-size: 18px;
        color: #8d33ff;
        line-height: 22px;
        text-align: center;
        font-style: normal;
        position: relative;
        top: 55px;
        left: 30px;
      }
    }
  }

  .banner-right {
    width: 38%;
    border-radius: 8px;
    margin-left: 0;
    background-repeat: no-repeat;
    height: 160px;
    position: relative;
    overflow: hidden;
    /* 固定高度 */
    background: linear-gradient(135deg, #4a90ff 0%, #2f80ed 100%);

    /* lite 模式：左卡隐藏后让批量卡占满整行 */
    &.banner-right--solo {
      width: 100%;
    }

    .banner-hero {
      position: absolute;
      top: 50%;
      right: 32px;
      transform: translateY(-50%);
      height: 140px;
      width: auto;
      border-radius: 8px;
      object-fit: cover;
      pointer-events: none;
      user-select: none;
    }

    .title-box {
      padding: 32px 0px 0px 32px;

      .h1 {
        font-family: Alimama FangYuanTi VF-Bold, Alimama FangYuanTi VF-Bold;
        font-weight: normal;
        font-size: 32px;

        color: #ffffff;
        line-height: 48px;
        letter-spacing: 4px;
        font-style: normal;
      }

      .text {
        font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
        font-weight: 400;
        font-size: 12px;
        color: rgba(255, 255, 255, 0.8);
        line-height: 20px;
        letter-spacing: 2px;
        font-style: normal;
        margin-top: 4px;


      }

      .link {
        width: 108px;
        height: 32px;
        background: #ffffff;
        cursor: pointer;
        border-radius: 27px;
        justify-content: center;
        align-items: center;
        display: flex;
        margin-top: 10px;

        .link-text {
          font-family: HarmonyOS Sans SC, HarmonyOS Sans SC;
          font-weight: bold;
          font-size: 14px;
          color: #2f80ed;
          line-height: 20px;
          font-style: normal;
          text-transform: none;
        }

        img {
          margin-left: 4px;
          width: 12px;
        }
      }
    }
  }

  .quick-entry {
    width: 140px;
    height: 32px;
    position: absolute;
    left: 50%;
    bottom: 18px;
    transform: translateX(-50%);
    background: rgba(255, 255, 255, 0.96);
    border-radius: 27px;
    display: flex;
    justify-content: center;
    align-items: center;
    cursor: pointer;
    color: #2f80ed;
    font-size: 13px;
    font-weight: 700;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.12);
  }
}
</style>
