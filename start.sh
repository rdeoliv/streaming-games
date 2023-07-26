#!/bin/bash
#set -e

PRJ_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
UTILS_DIR="${PRJ_DIR}/utils"
TMP_FOLDER="${PRJ_DIR}/tmp"
TFS_PATH="${PRJ_DIR}/terraform/aws"
STATE_FILE_PATH="${TFS_PATH}/terraform.tfstate"
LOGS_FOLDER="${PRJ_DIR}/logs"
LOG_FILE_PATH="${LOGS_FOLDER}/start.log"

export EXAMPLE="streaming-games"


function init_vars_from_tf_output() {
    ENVIRONMENT_ID=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".environment_id.value" -r)
    KAFKA_CLUSTER_API_KEY=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_cluster_api_key.value" -r)
    KAFKA_CLUSTER_API_SECRET=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_cluster_api_secret.value" -r)
    KAFKA_CLUSTER_ID=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_kafka_cluster_id.value" -r)
    KAFKA_CLUSTER_REST_ENDPOINT=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster.main.rest_endpoint" -r)
    KSQLDB_CLUSTER_ID=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster_id.value" -r)
    KSQLDB_ENDPOINT=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster_api_endpoint.value" -r)
    KSQLDB_CLUSTER_SERVICE_ACCOUNT_ID=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster_service_account_id.value" -r)
    KSQLDB_CLUSTER_API_KEY=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster_api_key.value" -r)
    KSQLDB_CLUSTER_API_SECRET=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".confluent_ksql_cluster_api_secret.value" -r)
    GAMES_URL=$(terraform output -json -state=${STATE_FILE_PATH} | jq ".Games.value" -r)


}

function create_infra_with_tf (){

    # DELTA_CONFIGS_DIR=delta_configs
    # source $DELTA_CONFIGS_DIR/env.delta

    # create_tfvars_file
    cd $TFS_PATH
    terraform init
    terraform apply --auto-approve

}

function check_mvn() {
  if [[ $(type mvn 2>&1) =~ "not found" ]]; then
    echo "'mvn' is not found. Install 'mvn' and try again"
    exit 1
  fi

  return 0
}


function validate_pre_reqs {

    ccloud::validate_version_cli 2.38.0 \
        && print_pass "confluent CLI version ok" \
        || exit 1

    ccloud::validate_logged_in_cli \
        && print_pass "logged into confluent CLI" \
        || exit 1

    check_jq \
        && print_pass "jq found" \
        || exit 1

    check_mvn \
        && print_pass "mvn found" \
        || exit 1
}

function create_ksqldb_app {

    MAX_WAIT=720
    echo "Waiting up to $MAX_WAIT seconds for Confluent Cloud ksqlDB cluster $KSQLDB_ENDPOINT to be UP"

    confluent environment use $ENVIRONMENT_ID

    #retry $MAX_WAIT ccloud::validate_ccloud_ksqldb_endpoint_ready $KSQLDB_ENDPOINT || exit 1

    #################################################################
    # Confluent Cloud ksqlDB application
    #################################################################
    KSQLDB_BASIC_AUTH_USER_INFO="${KSQLDB_CLUSTER_API_KEY}:${KSQLDB_CLUSTER_API_SECRET}"

    cd $PRJ_DIR

    export KSQLDB_ENDPOINT=$KSQLDB_ENDPOINT
    export KSQLDB_BASIC_AUTH_USER_INFO=$KSQLDB_BASIC_AUTH_USER_INFO
    export run_as_workshop=$run_as_workshop
    ./ksqldb/create_ksqldb_app.sh || exit 1

}

function start_demo {

    # Source demo-specific configurations
    source $PRJ_DIR/config/demo.cfg

    echo "run_as_workshop=$run_as_workshop"

    source $UTILS_DIR/demo_helper.sh

    validate_pre_reqs

    ccloud::prompt_continue_ccloud_demo || exit 1

    # Build Lambda Function with Maven
    cd $TFS_PATH/functions
    sh build.sh
    cd $PRJ_DIR

    create_infra_with_tf

    init_vars_from_tf_output

    KSQLDB_ALREADY_RUN_FILE="${LOGS_FOLDER}/ksqldb-already-run.log"
    if test -f "$KSQLDB_ALREADY_RUN_FILE"; then
        echo "KsqlDB was already executed for this workshop, we'll skip it for additional run of the start.sh . Destroy first"
    else
        create_ksqldb_app
        touch $KSQLDB_ALREADY_RUN_FILE
    fi

    welcome_screen

}


#http://patorjk.com/software/taag/#p=display&f=ANSI%20Regular&t=Streaming%20Games%0A%20Confluent%20
function welcome_screen {

    echo "*****************************************************************************************";
    echo "*                                                                                       *";
    echo "*    ███████ ████████ ██████  ███████  █████  ███    ███ ██ ███    ██  ██████           *";
    echo "*    ██         ██    ██   ██ ██      ██   ██ ████  ████ ██ ████   ██ ██                *";
    echo "*    ███████    ██    ██████  █████   ███████ ██ ████ ██ ██ ██ ██  ██ ██   ███          *";
    echo "*         ██    ██    ██   ██ ██      ██   ██ ██  ██  ██ ██ ██  ██ ██ ██    ██          *";
    echo "*    ███████    ██    ██   ██ ███████ ██   ██ ██      ██ ██ ██   ████  ██████           *";
    echo "*                                                                                       *";
    echo "*                                                                                       *";
    echo "*                 ██████   █████  ███    ███ ███████ ███████                            *";
    echo "*                ██       ██   ██ ████  ████ ██      ██                                 *";
    echo "*                ██   ███ ███████ ██ ████ ██ █████   ███████                            *";
    echo "*                ██    ██ ██   ██ ██  ██  ██ ██           ██                            *";
    echo "*                 ██████  ██   ██ ██      ██ ███████ ███████                            *";
    echo "*                                                                                       *";
    echo "*                                                                                       *";
    echo "*     ██████  ██████  ███    ██ ███████ ██      ██    ██ ███████ ███    ██ ████████     *";
    echo "*    ██      ██    ██ ████   ██ ██      ██      ██    ██ ██      ████   ██    ██        *";
    echo "*    ██      ██    ██ ██ ██  ██ █████   ██      ██    ██ █████   ██ ██  ██    ██        *";
    echo "*    ██      ██    ██ ██  ██ ██ ██      ██      ██    ██ ██      ██  ██ ██    ██        *";
    echo "*     ██████  ██████  ██   ████ ██      ███████  ██████  ███████ ██   ████    ██        *";
    echo "*                                                                                       *";
    echo "*                                                                                       *";
    echo "*             █████  ██████  ██     ██    ██      █████  ██      ██ ███████             *";
    echo "*            ██   ██ ██   ██ ██      ██  ██      ██   ██ ██  ██  ██ ██                  *";
    echo "*            ███████ ██████  ██        ██        ███████ ██ ████ ██ ███████             *";
    echo "*            ██   ██ ██   ██ ██        ██        ██   ██ ████  ████      ██             *";
    echo "*            ██   ██ ██████  ███████   ██        ██   ██ ███    ███ ███████             *";
    echo "*                                                                                       *";
    echo "*                                                                                       *";
    echo "*****************************************************************************************";
    echo
    echo
    echo "Handy link and Confluent info: "
    echo " - PLAY HERE --> ${GAMES_URL} ";
    echo "Created Kafka API KEY --> ${KAFKA_CLUSTER_API_KEY}";
    echo "Created Kafka API KEY secret --> ${KAFKA_CLUSTER_API_SECRET}";
    echo "Kafka Cluster endpoint --> ${KSQLDB_ENDPOINT}";
    echo
    echo "Cloud resources are provisioned and accruing charges. To destroy this demo and associated resources run ->"
    echo "    ./stop.sh"
    echo
}

mkdir $LOGS_FOLDER
start_demo 2>&1 | tee -a $LOG_FILE_PATH
