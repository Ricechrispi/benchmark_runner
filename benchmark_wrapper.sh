#!/usr/bin/env bash
echo "c o CALLSTR ${@}"

#TODO adapt these paths! also point in benchmark_setup to this file as "executable"
base_dir="/home/guests/cpriesne/master_project" # path to folder of benchmark_runner.py
conda_location="/home/guests/cpriesne/miniconda3"
conda_env_name="rb" # name of conda environment, default should be "rb"

ALGO=""
INSTANCE=""
PFILE=""
RUN_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
  -a | --algo)
    shift
    ALGO="${1}"
    shift
    ;;
  -i | --instance)
    shift
    INSTANCE="${1}"
    shift
    ;;
  -p | --pfile)
    shift
    PFILE="${1}"
    shift
    ;;
  -ri | --runid)
    shift
    RUN_ID="${1}"
    shift
    ;;
  *) # unknown argument
    echo "c o Unknown argument: ${1}"
    exit 1
    ;;
  esac
done

if [[ -z "${ALGO}" ]]; then
  echo "c o Please supply an algorithm"
  exit 1
fi
if [[ -z "${INSTANCE}" ]]; then
  echo "c o Please supply an instance file"
  exit 1
fi

echo "c o ================= TEST ENV VARS ======================"
echo "c o ENV ALGO = ${ALGO}"
echo "c o ENV INSTANCE = ${INSTANCE}"
echo "c o ENV PFILE = ${PFILE}"
echo "c o ENV RUN_ID = ${RUN_ID}"

echo "c o ================= SET PRIM INTRT HANDLING ============"
function interrupted() {
  echo "c o Sending kill to subprocess"
  kill -TERM $PID
  echo "c o Removing tmp files"
  [ ! -z "$tmpfile" ] && rm $tmpfile
}
function finish {
  echo "c o Removing tmp files"
  [ ! -z "$tmpfile" ] && rm $tmpfile
}
trap finish EXIT
trap interrupted TERM
trap interrupted INT

echo "c o ================= Changing directory ==================="
cd "${base_dir}"
if [[ $? -ne 0 ]]; then
  echo "c o Could not change directory to ${base_dir}. Exiting..."
  exit 1
fi

echo "c o ================= Activating Conda environment ======================"
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('${conda_location}/bin/conda' 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
  eval "$__conda_setup"
else
  if [ -f "${conda_location}/etc/profile.d/conda.sh" ]; then
    . "${conda_location}/etc/profile.d/conda.sh"
  else
    export PATH="${conda_location}/bin:$PATH"
  fi
fi
unset __conda_setup
conda activate "$conda_env_name"

echo "c o ================= Preparing tmpfiles ================="
tmpfile=$(mktemp /run/shm/result.XXXXXX)

echo "c o ================= Building Command String ============"
cmd="python benchmark_runner.py ${ALGO} --instance ${INSTANCE}"
if [[ -n "${PFILE}" ]]; then
  cmd+=" --param_file ${PFILE}"
fi
if [[ -n "${RUN_ID}" ]]; then
  cmd+=" --run_id ${RUN_ID}"
fi
echo "c o SOLVERCMD=$cmd"

echo "c o ================= Running Solver ====================="
myenv="TMPDIR=$TMPDIR"
env $myenv $cmd >$tmpfile &
PID=$!
wait $PID
exit_code=$?
echo "c o ================= Solver Done ========================"
echo "c o benchmark_wrapper: Solver finished with exit code=${exit_code}"
echo "c f RET=${exit_code}"

exit $exit_code
