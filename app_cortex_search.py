# Import Python packages
import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd
from snowflake.snowpark import Session

st.set_page_config(layout="wide")


@st.cache_resource
def get_active_session():
    return Session.builder.config("connection_name", "devrel").getOrCreate()


session = get_active_session()
session.use_schema("DATA")
model_name = "mistral-large"

st.header(f":speech_balloon: Cortex Search: Document Assistant")


@st.cache_data(show_spinner=True)
def get_context_docs():
    docs_available = session.sql("ls @DOCS").collect()
    list_docs = []
    for doc in docs_available:
        list_docs.append(doc["name"])
    return list_docs


def main():
    with st.expander("Available Documents"):
        list_docs = get_context_docs()
        st.dataframe(list_docs)

    init_messages()

    # Display chat messages from history on app rerun
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Accept user input
    if question := st.chat_input(
        "What would you like to know about our product offerings?"
    ):
        # Add user message to chat history
        st.session_state.messages.append({"role": "user", "content": question})
        # Display user message in chat message container
        with st.chat_message("user"):
            st.markdown(question)
        # Display assistant response in chat message container
        with st.chat_message("assistant"):
            message_placeholder = st.empty()

            question = question.replace("'", "")

            with st.spinner(f"Processing..."):
                response = complete(question)
                res_text = response[0].RESPONSE

                res_text = res_text.replace("'", "")
                message_placeholder.markdown(res_text)

        st.session_state.messages.append({"role": "assistant", "content": res_text})


def init_messages():
    # Initialize chat history
    if "messages" not in st.session_state:
        st.session_state.messages = []


def get_similar_chunks(question):
    cmd = """
        with results as
        (SELECT RELATIVE_PATH,
           VECTOR_COSINE_SIMILARITY(docs_chunks_table.chunk_vec,
                    SNOWFLAKE.CORTEX.EMBED_TEXT_768('e5-base-v2', ?)) as similarity,
           chunk
        from docs_chunks_table
        order by similarity desc
        limit ?)
        select chunk, relative_path from results 
    """

    df_chunks = session.sql(cmd, params=[question, num_chunks]).to_pandas()

    df_chunks_lenght = len(df_chunks) - 1

    similar_chunks = ""
    for i in range(0, df_chunks_lenght):
        similar_chunks += df_chunks._get_value(i, "CHUNK")

    similar_chunks = similar_chunks.replace("'", "")
    return similar_chunks


def get_chat_history():
    # Get the history from the st.session_stage.messages according to the slide window parameter
    chat_history = []

    start_index = max(0, len(st.session_state.messages) - slide_window)
    for i in range(start_index, len(st.session_state.messages) - 1):
        chat_history.append(st.session_state.messages[i])

    return chat_history


def summarize_question_with_history(chat_history, question):
    # To get the right context, use the LLM to first summarize the previous conversation
    # This will be used to get embeddings and find similar chunks in the docs for context

    prompt = f"""
        Based on the chat history below and the question, generate a query that extend the question
        with the chat history provided. The query should be in natual language. 
        Answer with only the query. Do not add any explanation.
        
        <chat_history>
        {chat_history}
        </chat_history>
        <question>
        {question}
        </question>
        """

    cmd = """
            select snowflake.cortex.complete(?, ?) as response
          """
    df_response = session.sql(cmd, params=[model_name, prompt]).collect()
    sumary = df_response[0].RESPONSE
    sumary = sumary.replace("'", "")

    return sumary


def create_prompt(question):
    chat_history = get_chat_history()

    if chat_history != []:  # There is chat_history, so not first question
        question_summary = summarize_question_with_history(chat_history, question)
        prompt_context = get_similar_chunks(question_summary)
    else:
        prompt_context = get_similar_chunks(
            question
        )  # First question when using history

    prompt = f"""
           You are an expert chat assistance that extracs information from the CONTEXT provided
           between <context> and </context> tags.
           You offer a chat experience considering the information included in the CHAT HISTORY
           provided between <chat_history> and </chat_history> tags..
           When ansering the question contained between <question> and </question> tags
           be concise and do not hallucinate. 
           If you don't have the information just say so.
           
           Do not mention the CONTEXT used in your answer.
           Do not mention the CHAT HISTORY used in your asnwer.
           
           <chat_history>
           {chat_history}
           </chat_history>
           <context>          
           {prompt_context}
           </context>
           <question>  
           {question}
           </question>
           Answer: 
           """

    return prompt


def complete(question):
    prompt = create_prompt(question)
    cmd = """
            select snowflake.cortex.complete(?, ?) as response
          """

    df_response = session.sql(cmd, params=[model_name, prompt]).collect()
    return df_response


num_chunks = 2  # Changing this value may affect a particular LLM's response
slide_window = 7  # Sliding window for "remembering" last n number of conversations

if __name__ == "__main__":
    main()


########## Questions to ask:

# 1) What kind of service does Gregory have?

#  In Japanese: グレゴリーにはどんな奉仕がありますか?
#  In Spanish: ¿Qué tipo de servicio tiene Gregory?

# 2) Was he charged with roaming fees?

#  In Japanese: 彼はローミング料金を請求されましたか?
#  In Spanish: ¿Se le cobraron tarifas de roaming?
