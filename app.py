import json
import os
import pandas as pd
import streamlit as st
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
from snowflake.cortex import Complete, Translate, ExtractAnswer, Sentiment, Summarize


st.set_page_config(layout="wide")

supported_languages = {
    "German": "de",
    "French": "fr",
    "Korean": "ko",
    "Portuguese": "pt",
    "English": "en",
    "Italian": "it",
    "Russian": "ru",
    "Swedish": "sv",
    "Spanish": "es",
    "Japanese": "ja",
    "Polish": "pl",
}

large_llms = ["llama3-70b", "mistral-large"]
medium_llms = ["snowflake-arctic", "reka-flash", "mixtral-8x7b", "llama2-70b-chat"]
small_llms = ["llama3-8b", "mistral-7b", "gemma-7b"]


@st.cache_resource
def get_active_session():
    return Session.builder.configs(
        {
            "account": "sfdevrel",
            "user": os.getenv("SNOWFLAKE_USER"),
            "password": os.getenv("SNOWFLAKE_PASSWORD"),
            "role": os.getenv("SNOWFLAKE_ROLE"),
            "database": os.getenv("SNOWFLAKE_DATABASE"),
            "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE"),
        }
    ).getOrCreate()


session = get_active_session()


@st.cache_data
def english_transcripts():
    return (
        session.table("CALL_TRANSCRIPTS")
        .select("TRANSCRIPT")
        .filter(col("language") == "English")
        .to_pandas()
    )


st.title("Snowflake Cortex LLM Functions Demo")
st.sidebar.selectbox(
    "Choose Model",
    medium_llms + small_llms + large_llms,
    key="llm_model",
)


def complete():
    st.subheader("COMPLETE")
    prompt = st.text_area(
        "Enter a text:",
        placeholder="How can I help you?",
        label_visibility="hidden",
    )
    if prompt:
        out = Complete(st.session_state.llm_model, prompt, session)
        st.markdown(out)


def translate():
    st.subheader("TRANSLATE")
    langs = sorted(supported_languages)
    col1, col2 = st.columns(2)
    with col1:
        from_lang = st.selectbox("**:green[From] Language:**", langs)
    with col2:
        to_lang = st.selectbox("**:orange[To] Language:**", langs)
    prompt = st.text_area(
        "Enter a text to translate:",
        placeholder="How are you ?",
        label_visibility="hidden",
    )
    if prompt:
        out = Translate(
            prompt,
            supported_languages[from_lang],
            supported_languages[to_lang],
            session,
        )
        st.write(out)


def sentiment():
    st.subheader("SENTIMENT")
    st.markdown(
        """
- :blush: : :green[Positive]
- :neutral_face: :  :orange[Neutral]
- :disappointed:  : :red[Negative]
"""
    )
    prompt = st.text_area(
        "Enter a text to translate:",
        placeholder="How are you ?",
        label_visibility="hidden",
    )
    if prompt:
        out = Sentiment(
            prompt,
            session,
        )
        # Round to the nearest of -1, 0, or 1 based on the absolute value
        score = int(round(out))
        st.write(f"Actual sentiment score `{out}` rounded to `{score}`")
        if score == 0:
            st.subheader(":neutral_face:")
        elif score == 1:
            st.subheader(":blush:")
        elif score == -1:
            st.subheader(":disappointed:")


def summarize():
    st.subheader("SUMMARIZE")
    uploaded_file = st.file_uploader(
        "Choose a :red[**text**] file to summarize:",
        label_visibility="hidden",
    )
    if uploaded_file is not None:
        # To read file as bytes:
        str_bytes = uploaded_file.getvalue()
        if str_bytes:
            str = uploaded_file.getvalue().decode("utf-8")
            if str:
                out = Summarize(str, session)
                st.write(out)


def extract_answer():
    st.subheader("EXTRACT ANSWER")
    question = st.text_input(
        "Question",
        placeholder="Type a question",
        label_visibility="hidden",
    )
    uploaded_file = st.file_uploader(
        "Choose a :red[**text**] file to look for answers:",
        label_visibility="hidden",
    )
    if question is not None and uploaded_file is not None:
        # To read file as bytes:
        str_bytes = uploaded_file.getvalue()
        if str_bytes:
            str = uploaded_file.getvalue().decode("utf-8")
            if str:
                out = ExtractAnswer(str, question, session)
                if out:
                    df = pd.DataFrame(json.loads(out))
                    st.dataframe(df, hide_index=True)


def json_summary():
    st.subheader("JSON Summary")
    df = english_transcripts()
    event = st.dataframe(
        df,
        key="transcript",
        hide_index=True,
        on_select="rerun",
        use_container_width=True,
        selection_mode=["single-row"],
    )
    if event.selection and len(event.selection.rows) > 0:
        sel_transcript = df.iloc[event.selection.rows[0]]["TRANSCRIPT"]
        if sel_transcript:
            sel_transcript = sel_transcript.replace("'", "\\'")
            prompt = f"""
        [INST]
        Summarize this transcript in less than 200 words. Put the product name, defect if any, and summary in JSON format for
        call transcript:
        {sel_transcript}
        [/INST]
        """
            with st.spinner("Loading ..."):
                out = Complete(st.session_state.llm_model, prompt, session)
                try:
                    json.loads(out)
                    st.json(out)
                except ValueError:
                    st.write(out)


st.sidebar.selectbox(
    "Select a Snowflake Cortex Function",
    sorted(
        [
            "Complete",
            "Translate",
            "Summarize",
            "Sentiment",
            "Json Summary",
            "Extract Answer",
        ]
    ),
    key="llm_func",
)

func_name = str.lower(st.session_state.llm_func)
if func_name is not None:
    globals()[func_name.replace(" ", "_")]()
