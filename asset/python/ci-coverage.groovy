def prepare(remote) {
    def containerId = sshCommand(
        remote: remote,
        command: "cd '${params.APP_DIR}' && docker compose ps -q '${env.PACKAGE_NAME}'"
    ).trim()
    if (!containerId) {
        error("未找到 ${env.PACKAGE_NAME} 的运行容器，无法采集 e2e 覆盖率")
    }
    return [containerId: containerId]
}

def collect(remote, context) {
    def containerId = context.containerId
    def remoteCoverageArchive = "/tmp/${env.PACKAGE_NAME}-${env.BUILD_NUMBER}-coverage.tar.gz"
    sshCommand remote: remote, command: "docker kill --signal=USR1 '${containerId}'"
    sshCommand remote: remote, command: "docker exec '${containerId}' sh -c 'for attempt in 1 2 3 4 5 6 7 8 9 10; do test -s /work/tanqi/.coverage && exit 0; sleep 1; done; exit 1'"
    sshCommand remote: remote, command: "docker exec '${containerId}' coverage xml -o /tmp/coverage.xml"
    sshCommand remote: remote, command: "docker exec '${containerId}' coverage html -d /tmp/coverage-report"
    sshCommand remote: remote, command: "docker exec '${containerId}' coverage report"
    sshCommand remote: remote, command: "docker exec '${containerId}' tar -C /tmp -czf /tmp/coverage-report.tar.gz coverage.xml coverage-report"
    sshCommand remote: remote, command: "docker cp '${containerId}:/tmp/coverage-report.tar.gz' '${remoteCoverageArchive}'"
    sh 'mkdir -p out/coverage'
    sshGet remote: remote, from: remoteCoverageArchive, into: 'out/coverage/coverage-report.tar.gz', override: true
    sshRemove remote: remote, path: remoteCoverageArchive
    sh 'bash ./ci-coverage-report.sh'
}

return this
