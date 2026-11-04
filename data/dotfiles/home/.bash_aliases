# zoxide
alias cd="z"
alias cdi="zi"

#alias vim="nvim"

vim(){
    session_name=vim-$(basename "$PWD")
    tmux new-session -s "$session_name" "nvim $*"
}

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

function getLocalToken(){
curl --request POST --url 'http://localhost:8080/realms/8X/protocol/openid-connect/token?expectedFileReceptionTimeStart=2020-10-25T14%3A57%3A05.257Z&expectedFileReceptionTimeEnd=2022-10-26T14%3A57%3A05.257Z' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data username=sofiene \
--data password="$GETLOCALTOKEN_PASSWORD" \
--data grant_type=password \
--data client_id=adad-front \
--data client_assertion="$GETLOCALTOKEN_CLIENT_ASSERTION" | jq '.access_token' | cut -d '"' -f 2 | xclip -selection clipboard && echo "Access token copied to keyboard."
}

function getRemoteTokenDev(){
curl --request POST --url 'https://security.dev.adad.io/realms/6X/protocol/openid-connect/token?expectedFileReceptionTimeStart=2020-10-25T14%3A57%3A05.257Z&expectedFileReceptionTimeEnd=2022-10-26T14%3A57%3A05.257Z' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data username=sofiene \
--data password="$GETREMOTETOKENDEV_PASSWORD" \
--data grant_type=password \
--data client_id=adad-front \
--data client_assertion="$GETREMOTETOKENDEV_CLIENT_ASSERTION" | jq '.access_token' | cut -d '"' -f 2 | xclip -selection clipboard && echo "Access token copied to keyboard."
}

function getRemoteTokenUat(){
curl --request POST --url 'https://security.uat.adad.io/realms/8X/protocol/openid-connect/token?expectedFileReceptionTimeStart=2020-10-25T14%3A57%3A05.257Z&expectedFileReceptionTimeEnd=2022-10-26T14%3A57%3A05.257Z' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data username=sofiene \
--data password="$GETREMOTETOKENUAT_PASSWORD" \
--data grant_type=password \
--data client_id=adad-front \
--data client_assertion="$GETREMOTETOKENUAT_CLIENT_ASSERTION" | jq '.access_token' | cut -d '"' -f 2 | xclip -selection clipboard && echo "Access token copied to keyboard."
}

function switchAwsProfileDev(){
export AWS_PROFILE=default
export AWS_DEFAULT_REGION=eu-north-1
aws eks update-kubeconfig  --region "eu-north-1" --name dev-adad-core-cluster	
}

function switchAwsProfileUat(){
export AWS_PROFILE=adad-uat
export AWS_DEFAULT_REGION=eu-west-3
aws eks update-kubeconfig  --region "eu-west-3" --name uat-adad-core-cluster

}

function switchAwsProfileProd(){
export AWS_PROFILE=adad-prod
export AWS_DEFAULT_REGION=eu-west-3
aws eks update-kubeconfig  --region "eu-west-3" --name prod-adad-core-cluster
}

function switchAwsProfileStaging(){
export AWS_DEFAULT_REGION=eu-north-1
export AWS_PROFILE=default 
aws eks update-kubeconfig --region "eu-north-1" --name dev-adad-core-cluster
}

function switchAwsProfilePoc(){
    export AWS_PROFILE=adad-uat 
    export AWS_DEFAULT_REGION=eu-west-3
    aws eks update-kubeconfig --region "eu-west-3" --name poc-adad-core-cluster
}

function createSSHTunnelDev(){
    ssh -i ~/keys/dev.pem -N -p 22122 -L 15432:dev2-adad-core-rds-cluster-new.cluster-ckptxjuwnrn4.eu-west-3.rds.amazonaws.com:5432 ec2-user@$1
}

function createSSHTunnelUat(){
    #ssh -i ~/.ssh/worker.pem -N -p 22122 -L 15432:dev2-adad-core-rds-cluster-new.cluster-ckptxjuwnrn4.eu-west-3.rds.amazonaws.com:5432 ec2-user@$1
    #ssh -i ~/keys/uat.pem -N -p 22122 -L 15432:uat-adad-rds-cluster-from-prod-cluster.cluster-cug0tudcl9bb.eu-west-3.rds.amazonaws.com:5432 ec2-user@$1
    ssh -i ~/keys/uat.pem -N -p 22122 -L 15432:rds.uat.adad.io:5432 ec2-user@$1
}

function createSSHTunnelUattoProd(){
    #ssh -i ~/.ssh/worker.pem -N -p 22122 -L 15432:dev2-adad-core-rds-cluster-new.cluster-ckptxjuwnrn4.eu-west-3.rds.amazonaws.com:5432 ec2-user@$1
    ssh -i ~/keys/uat.pem -N -p 22122 -L 15432:uat-adad-rds-cluster-from-prod-cluster.cluster-cug0tudcl9bb.eu-west-3.rds.amazonaws.com:5432 ec2-user@$1
}

function switchAwsProfileMiraDev(){
export AWS_PROFILE=mira-dev
export AWS_DEFAULT_REGION=eu-north-1
aws eks update-kubeconfig  --region "eu-north-1" --name rpa-dev-rpa-ai-cluster
}

alias ssh_tunnel_prod_dt='ssh -i ~/keys/prod-key.pem -N -p 22122 -L 15432:prod-adad-core-rds-cluster-new.cluster-cj2nxovdibd1.eu-west-3.rds.amazonaws.com:5432 ec2-user@'13.38.86.40

alias ssh_tunnel_prod_8x_cpd='ssh -i ~/keys/prod-key.pem -N -p 22122 -L 15432:cpd-8x-prod-cluster.cluster-cj2nxovdibd1.eu-west-3.rds.amazonaws.com:5432 ec2-user@'13.38.86.40

#alias get_bastion_id="bastion_id=\$(aws ec2 describe-instances --filters \"Name=tag:Name,Values=adad-ec2-bastion\" --query \"Reservations[].Instances[?State.Name=='running'].InstanceId\" --output text)"

get_bastion_id() {
  bastion_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=mnc-ec2-bastion" \
    --query "Reservations[].Instances[?State.Name=='running'].InstanceId" \
    --output text)
  echo "$bastion_id"
}


alias start_ssm_session_rds_prod_dt="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"shared-db-ro.prod.adad.internal\"]}'"
alias start_ssm_session_rds_prod_pr="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"pr-db-ro.prod.adad.internal\"]}'"
alias start_ssm_session_rds_prod_sk="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"sk-db.prod.adad.internal\"]}'"
alias start_ssm_session_rds_prod_5j="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"shared-db.prod.adad.internal\"]}'"


alias start_ssm_session_rds_prod_ay="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"ay-db-ro.prod.adad.internal\"]}'"
alias start_ssm_session_rds_prod_8x="aws ssm start-session --target \$bastion_id --document-name ADAD-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"rds-demo.prod.adad.internal\"]}'"
#alias start_ssm_session_sftp_prod="aws ssm start-session --target \$bastion_id --region eu-west-3 --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"22\"],\"localPortNumber\":[\"2222\"],\"host\":[\"35.180.150.157\"]}'"
alias start_ssm_session_sftp_prod="aws ssm start-session --target \$bastion_id --region eu-west-3 --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"2022\"],\"localPortNumber\":[\"2022\"],\"host\":[\"10.2.2.231\"]}'"


alias start_ssm_session_sftp_dev="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"2022\"],\"localPortNumber\":[\"2224\"],\"host\":[\"10.10.2.175\"]}'"
alias start_ssm_session_rds_dev="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"db.dev.adad.internal\"]}'"
alias start_ssm_session_rds_perf="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"perf-db.dev.adad.internal\"]}'"
alias start_ssm_session_rds_mira="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5599\"],\"host\":[\"ai-db.rpa.mnc.internal\"]}'"

alias start_ssm_session_rds_staging="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"db.dev.adad.internal\"]}'"
alias start_ssm_session_sftp_staging="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"2022\"],\"localPortNumber\":[\"2224\"],\"host\":[\"10.10.2.175\"]}'"

alias start_ssm_session_rds_uat="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"db.uat.adad.internal\"]}'"
#alias start_ssm_session_rds_poc_implem="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"db.uat.adad.internal\"]}'"
alias start_ssm_session_rds_ay_poc_uat="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"ay-db.uat.adad.internal\"]}'"

alias start_ssm_session_sftp_uat="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"2022\"],\"localPortNumber\":[\"2224\"],\"host\":[\"10.10.2.175\"]}'"


alias start_ssm_session_queue_dev="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"8162\"],\"localPortNumber\":[\"6789\"],\"host\":[\"b-7ad21af5-7539-4ec7-950d-3dbf976573e0-1.mq.eu-north-1.amazonaws.com\"]}'"
alias start_ssm_session_queue_prod="aws ssm start-session --target \$bastion_id --document-name TROUBLESHOOTING-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"8162\"],\"localPortNumber\":[\"6789\"],\"host\":[\"b-ab10e522-ace8-4069-9719-103b7bcd393d-1.mq.eu-west-3.amazonaws.com\"]}'"

alias start_ssm_session_rds_skiling="aws ssm start-session --target \$bastion_id --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"portNumber\":[\"5432\"],\"localPortNumber\":[\"5555\"],\"host\":[\"db.uat.adad.internal\"]}'"


alias run_adad_upstream_projects="/home/sofienejouini/adad_projects/runUpstreamProjects.sh"

alias log-viewer='/home/sofienejouini/log-viewer.sh'

alias restart_virtual_camera='sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"'

#Grant access to tables,sequence, procedure
#GRANT ALL ON ALL TABLES IN SCHEMA "8X" TO "staging_dbuser8x";
#GRANT ALL ON ALL SEQUENCES IN SCHEMA "8X" TO "staging_dbuser8x";
#GRANT ALL ON ALL PROCEDURES IN SCHEMA "8X" TO "staging_dbuser8x";
#GRANT ALL ON SCHEMA "8X" TO "staging_dbuser8x";
#ALTER DEFAULT PRIVILEGES IN SCHEMA  "8X" GRANT ALL ON TABLES TO "staging_dbuser8x";

#psql --host 127.0.0.1 --port 5432 --user postgres adad < backup.sql
#pg_dump --data-only --host 127.0.0.1 --port 5432 --user postgres adad --inserts --table datasource
