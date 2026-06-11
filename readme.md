# Co-Reading

Co-Reading은 시 텍스트를 입력하면 인공지능이 감정을 분석하고, 그 결과를 색채로 변환하여 시각화하는 프로그램이다.

본 프로젝트는 한국 근현대시 감정 분석 모델인 **KPoEM**, 감정–색채 매핑 데이터셋인 **KCoEM**, 그리고 **I.R.I 감성형용사 및 배색 스케일**을 결합하여 시–감정–색채 변환 알고리즘을 구현한다.

## Overview

Co-Reading 시스템은 하나의 시를 다음과 같은 과정으로 처리한다.

```text
Poem Text
   ↓
KPoEM Emotion Classification
   ↓
Primary / Secondary Emotion Selection
   ↓
Emotion Polarity Classification
   ↓
KCoEM-based Color Selection
   ↓
I.R.I-based Saturation / Brightness Adjustment
   ↓
Emotion–Color Visualization
```

## Main Algorithm

### 1. Poem Input

사용자는 시 텍스트를 입력한다.

```python
CoReadingPoem(user_input, flat_list)
```

입력된 시는 두 가지 방식으로 분석된다.

첫째, KPoEM 감정 분류 모델을 통해 시의 주요 감정을 예측한다.
둘째, Gemini 2.5 Flash 모델을 통해 시의 분위기에 가장 가까운 I.R.I 감성형용사 하나를 선택한다.

## 2. Emotion Classification

시 텍스트는 Hugging Face에 업로드된 KPoEM 감정 분류 모델을 통해 분석된다.

```python
REPO_ID = "AKS-DHLAB/KPoEM"
THRESH_HOLD = 0.3
```

KPoEM 모델은 시 텍스트를 입력받아 44개의 감정 라벨에 대한 예측값을 산출한다.
이후 threshold 0.3 이상인 감정들이 결과로 반환된다.

예측된 감정 중 `없음` 라벨은 제거되며, 감정 점수가 높은 순서대로 정렬된다.
그중 상위 두 개 감정이 각각 주감정(primary emotion)과 보조감정(secondary emotion)으로 선택된다.

```python
top_two_emotions = filter_emotions(result_emotions)
```

## 3. Emotion Polarity Classification

선택된 주감정과 보조감정은 긍정, 부정, 중립 감정군으로 분류된다.

```python
positive_emotions = [...]
negative_emotions = [...]
neutral_emotions = [...]
```

감정 조합에 따라 색채 배색 방식이 결정된다.

```text
긍정 + 긍정 → 유사색상
부정 + 부정 → 유사색상
긍정 + 부정 → 대비색상
부정 + 긍정 → 대비색상
중립 감정 포함 → 중립 배색
```

이 과정은 다음 함수에서 수행된다.

```python
color_mode = categorize_emotion(primary_emotion, secondary_emotion)
```

## 4. Primary Color Selection

주감정에 해당하는 색상 후보는 KCoEM 데이터셋에서 검색된다.

```python
filtered_top_emotion = df[df["KOTE_emotion_name"] == primary_emotion]
primary_color = get_color(filtered_top_emotion)
```

색상 후보가 여러 개일 경우 `priority` 값이 가장 낮은 색상이 우선 선택된다.
동일한 priority를 가진 후보가 여러 개 있으면 그중 하나를 무작위로 선택한다.

## 5. Secondary Color Selection

보조색은 주색의 먼셀 색상환 정보를 기준으로 선택된다.

먼저 주색의 색상 코드에서 다음 정보를 계산한다.

```python
primary_color_info = get_color_info(primary_color)
```

이 함수는 주색을 기준으로 다음 색상군을 산출한다.

* 중심 색상
* 유사색상군
* 대비색상군
* 보색

이후 감정 조합에 따라 보조색 선택 방식이 달라진다.

### Similar Color Mapping

주감정과 보조감정이 같은 정서 방향을 가질 경우 유사색상 배색을 적용한다.

```python
similar_mapping(primary_color_info, secondary_emotion, df)
```

보조감정의 색상 후보 중 주색과 인접한 색상군이 있으면 이를 우선 선택한다.
일치하는 유사색상이 없으면 보조감정의 색상 후보 중 priority가 높은 색상을 선택한다.

### Contrast Color Mapping

주감정과 보조감정이 서로 다른 정서 방향을 가질 경우 대비색상 배색을 적용한다.

```python
contrast_mapping(primary_color_info, secondary_emotion, df)
```

보조감정의 색상 후보 중 주색의 보색 또는 대비색상군에 해당하는 색상을 우선 선택한다.
일치하는 색상이 없으면 보조감정의 색상 후보 중 priority가 높은 색상을 선택한다.

### Neutral Mapping

주감정 또는 보조감정에 중립 감정이 포함될 경우 별도의 중립 배색 방식을 적용한다.

```python
neutral_mapping(primary_color_info, secondary_emotion, df)
```

## 6. I.R.I-based Tone Adjustment

Co-Reading 알고리즘은 단순히 감정을 색상으로 대응시키는 데서 끝나지 않는다.
Gemini 2.5 Flash 모델은 시의 전체 분위기에 해당하는 감성형용사를 하나 선택한다.

```python
reading = classify_poem_label(user_input, flat_list)
```

선택된 형용사는 I.R.I 감성형용사 데이터에서 해당 형용사군으로 변환된다.

```python
group_name = find_adjective_group(reading, grouped_adjectives)
```

이후 해당 형용사군에 속하는 I.R.I 배색그룹을 찾고, 그중 하나의 배색그룹을 선택한다.

```python
palette_ids = IRI_colors_df["배색그룹id"].dropna().unique()
chosen_palette_id = random.choice(palette_ids)
```

선택된 I.R.I 배색그룹에서 두 개의 색상 조합을 가져온 뒤, 그 색상의 채도와 명도를 KCoEM 기반 주색·보조색에 적용한다.

```python
updated_colors = update_saturation_brightness(
    processed_primary_color,
    processed_secondary_color,
    palette_result
)
```

즉, 최종 색상은 다음 두 층위가 결합된 결과이다.

```text
Hue 색상 방향 → KPoEM 감정 + KCoEM 감정–색채 매핑
Saturation / Brightness 색조 조정 → I.R.I 감성형용사 배색 스케일
```

## 7. Visualization

최종적으로 선택된 주색과 보조색은 HSB에서 RGB로 변환되어 시각화된다.

```python
emotion_to_colors(
    [primary_emotion, secondary_emotion, reading],
    poem_colors
)
```

시각화 결과는 7:3 비율의 색상 블록으로 제시된다.

```text
Primary Color : 70%
Secondary Color : 30%
```

이를 통해 사용자는 시의 주된 감정과 보조 감정, 그리고 AI 독자가 선택한 감성형용사를 색채 조합으로 확인할 수 있다.

## Core Components

### KPoEM

한국 근현대시를 대상으로 학습된 다중감정 분류 모델이다.
시 텍스트를 입력받아 44개 감정 라벨에 대한 예측 결과를 산출한다.

### KCoEM

한국어 감정과 색채의 대응 관계를 정리한 감정–색채 매핑 데이터셋이다.
본 알고리즘에서는 KPoEM 감정 라벨을 색상 후보로 변환하는 데 사용된다.

### I.R.I Color Image Scale

감성형용사와 배색 이미지를 연결하기 위한 색채 체계이다.
본 알고리즘에서는 Gemini가 선택한 감성형용사를 바탕으로 최종 색상의 채도와 명도를 조정하는 데 사용된다.

### Gemini 2.5 Flash

시 텍스트를 읽고 I.R.I 감성형용사 목록 중 하나를 선택하는 AI 독자 역할을 수행한다.

## Example

```python
CoReadingPoem(
    """
    눈은 푹푹 나리고
    아름다운 나타샤는 나를 사랑하고
    어데서 흰 당나귀도 오늘밤이 좋아서 응앙응앙 울을 것이다
    """,
    flat_list
)
```

위 코드는 입력된 시 텍스트를 분석하여 다음 결과를 생성한다.

```text
1. KPoEM 기반 주감정·보조감정 추출
2. Gemini 기반 감성형용사 선택
3. KCoEM 기반 주색·보조색 선택
4. I.R.I 기반 채도·명도 조정
5. 최종 감정–색채 시각화
```

## Purpose

Co-Reading은 시를 단순히 감정 라벨로 분류하는 시스템이 아니라, 인간의 문학적 읽기와 인공지능의 감정 분석 결과가 색채를 매개로 함께 제시되는 읽기 환경을 실험하기 위한 프로토타입이다.

본 프로젝트는 시 텍스트를 감정 데이터로 분석하고, 그 결과를 색채 이미지로 변환함으로써 문학 작품을 감각적으로 탐색하는 새로운 디지털 인문학 방법론을 제안한다.


## Project Structure

### backend

감정 분석과 시각화 결과를 생성하는 코드가 포함되어 있습니다.

- `shap/`
  - SHAP 기반 중요 단어 분석 결과 저장
- `KPoEM_heatmap.ipynb`
  - 감정 히트맵 생성
- `KPoEM_wordcloud.ipynb`
  - 워드클라우드 생성
- `poet_emotion_distribution.ipynb`
  - 시인별 감정 분포 분석
- `poet_SHAP_batched_run.ipynb`
  - SHAP 분석 수행

### frontend

사용자가 실제로 감정 분석 결과를 확인할 수 있는 웹 인터페이스입니다.

- `close_reading/`
  - 개별 시를 중심으로 감정을 탐색하는 화면
- `distant_reading/`
  - 시인 전체의 감정 경향을 확인하는 화면
- `co_reading/`
  -인간과 인공지능이 함께 시를 읽는 Co-Reading 인터페이스 사용자가 시를 선택하면 작품 전문이 표시됨 감정 분석 결과를 기반으로 감정–색채 시각화를 제공. 감정 정보를 색상 그라데이션과 범례 형태로 표현하여 새로운 시 읽기 경험을 제공.
  
- `source/`
  - 시인별 distant analysis HTML 결과 파일 저장
- `styles/`
  - CSS 스타일 파일
- `js/`
  - 인터페이스 동작을 위한 JavaScript 파일
- `img/`
  - 워드클라우드 이미지 파일 저장

## 주요 기능

* **Close Reading**

  * 개별 시 작품의 감정 분석 결과 탐색
  * 행 단위 감정 정보 및 주요 감정 확인

* **Distant Reading**

  * 시인별·작품별 감정 분포 시각화
  * 감정 히트맵을 통한 감정 패턴 탐색

* **Co-Reading**

  * 인간과 인공지능이 함께 시를 읽는 인터페이스 제공
  * 감정 분석 결과를 색채 시각화로 표현
  * 문학적 해석과 AI 분석 결과를 동시에 탐색 가능

* **Emotion Visualization**

  * 감정 히트맵(Heatmap) 제공
  * 감정 분포 시각화
  * 감정–색채 매핑(Color Mapping)

* **Explainable AI**

  * SHAP 기반 핵심 단어 분석
  * 워드클라우드를 통한 감정 특징어 시각화

* **Interactive Exploration**

  * 시인, 작품, 감정 정보를 웹 기반 환경에서 탐색
  * 다양한 읽기 방식을 결합한 디지털 인문학 인터페이스 제공


## 대상 시인

- 한용운
- 김소월
- 이상
- 임화
- 윤동주

## 목적

KPoEM Interface는 감정 데이터셋과 인공지능 분석 결과를 활용하여 한국 근현대시를 새로운 방식으로 읽고 탐색할 수 있는 디지털 인문학 연구 환경을 제공하는 것을 목표로 합니다.

## Resource

### 📖 KPoEM Dataset
- IRO LIM · Ji Haein · Koo Sul · Jung Song-yi · Yun Jonghoon · Byungjun Kim
- Repository: [Zenodo](https://zenodo.org/records/15598092), [HuggingFace](https://huggingface.co/datasets/AKS-DHLAB/KPoEM)

### 🤖 KPoEM Emotion Classification Model
- IRO LIM · Ji Haein · Byungjun Kim
- Repository: [HuggingFace](https://huggingface.co/AKS-DHLAB/KPoEM)

> ⬇️ 본 데이터셋과 감정 분류 모델은 공동연구를 통해 개발되었으며, 상세 내용은 아래 관련 논문을 참고하기 바란다.
>
> Lim, I., Ji, H., & Kim, B. (2026). KPoEM: A human-annotated dataset for emotion classification and RAG-based poetry generation in Korean modern poetry. The Review of Korean Studies, 29(1), 161–206. https://doi.org/10.25024/review.2026.29.1.161

---

### 🎨 KCoEM Dataset
- IRO LIM
- Repository: [Zenodo](https://zenodo.org/records/19464212)

### 🌈 KPoEM Interface
- IRO LIM
- Repository: [Github](https://github.com/poet-developer/KPoEMInterface)
- Pages : [KPoEM Interface Prototype](https://poet-developer.github.io/KPoEMInterface/)
