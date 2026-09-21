def prepare(remote) {
    return [:]
}

def collect(remote, context) {
    if (env.CI == 'true') {
        sh 'bash ./ci-coverage-report.sh'
    }
}

return this
