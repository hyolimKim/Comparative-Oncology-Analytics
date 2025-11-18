/******************************************************************************
 * 연구 제목: 위스콘신 유방암 데이터의 세포핵 특징을 이용한 악성/양성 분류 모델 개발
 * 작성자: hyolim_Kim 
 * 작성일: 2025-11-19
 *
 * [연구 개요]
 * - 목적: 세포의 형태학적 특징(30개)을 이용하여 유방암 악성(M)/양성(B) 여부 분류
 * - 주요 기법: SVM, Random Forest, PCA (주성분 분석)
 * - 데이터: Kaggle Breast Cancer Wisconsin (Diagnostic) Data Set
 ******************************************************************************/

/* =================================================================================
   [필수] 1. 환경 설정 및 데이터 불러오기
   이 부분은 변수명에 공백(띄어쓰기)이 들어가는 것을 막아주는 핵심 코드입니다.
   ================================================================================= */
OPTIONS VALIDVARNAME=V7; /* 변수명의 공백을 밑줄(_)로 자동 변환 */

PROC IMPORT OUT= WORK.breast_cancer
            /* 중요: 아래 경로를 본인의 파일 경로로 꼭 수정하세요! */
            DATAFILE= "/home/u63566986/data.csv" 
            DBMS=CSV REPLACE;
    GETNAMES=YES;
RUN;

/* 잘 들어왔는지 확인 (변수명이 radius_mean 처럼 되어야 성공!) */
PROC CONTENTS DATA=breast_cancer VARNUM; 
RUN;

/* =================================================================================
   2. 데이터 전처리 (Data Preprocessing)
   ================================================================================= */
DATA breast_cancer_clean;
    SET breast_cancer;
    
    /* 타겟 변수 숫자 변환 (악성 M=1, 양성 B=0) */
    IF diagnosis = 'M' THEN diagnosis_binary = 1;
    ELSE IF diagnosis = 'B' THEN diagnosis_binary = 0;
    
    /* 불필요한 변수 제거 */
    DROP id; 
RUN;

/* =================================================================================
   3. 데이터 분할 (Train 70% : Test 30%)
   ================================================================================= */
PROC SURVEYSELECT DATA=breast_cancer_clean OUT=dataset_split 
                  METHOD=SRS RATE=0.7 SEED=12345 OUTALL;
RUN;

DATA train_data test_data;
    SET dataset_split;
    IF Selected = 1 THEN OUTPUT train_data; /* 학습용 */
    ELSE OUTPUT test_data;                  /* 평가용 */
RUN;

/* =================================================================================
   4. 모델링 1: 의사결정나무 (Decision Tree)
   * 랜덤포레스트 대신 사용: 변수 중요도와 규칙을 시각적으로 확인 가능
   * SAS ODA 무료 버전에서도 100% 작동함 (PROC HPSPLIT)
   ================================================================================= */
TITLE "Model 1: Decision Tree Analysis";

PROC HPSPLIT DATA=train_data MAXDEPTH=5; /* 나무 깊이 제한 */
    CLASS diagnosis_binary; 
    MODEL diagnosis_binary = radius_mean--fractal_dimension_worst;
    
    /* 가지치기(Pruning) 설정: 과적합 방지 */
    PRUNE COSTCOMPLEXITY;
    
    /* 결과 시각화 옵션 */
    OUTPUT OUT=tree_output; 
RUN;

/* =================================================================================
   5. 모델링 2: 로지스틱 회귀분석 (Logistic Regression)
   * SVM 대신 사용: 암 진단 분류에서 가장 표준적으로 쓰이는 강력한 모델
   * 단계적 선택법(Stepwise)을 써서 중요한 변수만 자동으로 골라냄
   ================================================================================= */
TITLE "Model 2: Logistic Regression (Stepwise Selection)";

PROC LOGISTIC DATA=train_data DESCENDING PLOTS(ONLY)=ROC;
    /* Stepwise: 중요한 변수만 남기고 나머지는 제거하여 모델 성능 최적화 */
    MODEL diagnosis_binary(EVENT='1') = radius_mean--fractal_dimension_worst 
          / SELECTION=STEPWISE SLENTRY=0.05 SLSTAY=0.05;
          
    /* 만들어진 모델로 테스트 데이터 점수 매기기(Scoring) */
    SCORE DATA=test_data OUT=logistic_score;
RUN;

/* =================================================================================
   6. 최종 성능 평가 (ROC Curve & 정확도 확인)
   ================================================================================= */
TITLE "Final Evaluation: ROC Curve on Test Data";

/* 위에서 구한 점수(P_1)를 바탕으로 테스트 데이터에서의 성능 그래프 그리기 */
PROC LOGISTIC DATA=logistic_score PLOTS(ONLY)=ROC;
    MODEL diagnosis_binary(EVENT='1') = P_1 / NOFIT; 
RUN;