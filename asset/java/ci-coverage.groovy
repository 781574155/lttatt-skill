def prepare(remote) {
    def containerId = sshCommand(
        remote: remote,
        command: "cd '${params.APP_DIR}' && docker compose ps -q '${env.PACKAGE_NAME}'"
    ).trim()
    if (!containerId) {
        error("未找到 ${env.PACKAGE_NAME} 的运行容器，无法采集 e2e 覆盖率")
    }

    sshCommand remote: remote, command: "docker exec '${containerId}' java -jar /opt/jacoco/jacococli.jar dump --address 127.0.0.1 --port 6300 --destfile /tmp/jacoco-startup.exec --reset"
    return [containerId: containerId]
}

def collect(remote, context) {
    def containerId = context.containerId
    def remoteCoverageFile = "/tmp/${env.PACKAGE_NAME}-${env.PACKAGE_VERSION}-jacoco.exec"
    sshCommand remote: remote, command: "docker exec '${containerId}' java -jar /opt/jacoco/jacococli.jar dump --address 127.0.0.1 --port 6300 --destfile /tmp/jacoco.exec --reset"
    sshCommand remote: remote, command: "docker cp '${containerId}:/tmp/jacoco.exec' '${remoteCoverageFile}'"
    sh 'mkdir -p out/coverage'
    sshGet remote: remote, from: remoteCoverageFile, into: 'out/coverage/jacoco.exec', override: true
    sshRemove remote: remote, path: remoteCoverageFile
    sh 'bash ./ci-coverage-report.sh'
}

return this
