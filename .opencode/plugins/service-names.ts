import type { Plugin } from "@opencode-ai/plugin"

const SERVICES_FILE = "/etc/Wywy-Website-Control/services.txt"
const CONTEXT_FILE = "/etc/Wywy-Website-Control/.opencode/services-context.md"

interface Service {
  alias: string
  repo: string
  path: string
}

function parseServices(text: string): Service[] {
  return text
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [alias, repo] = line.split(",")
      return {
        alias: alias.trim(),
        repo: repo.trim(),
        path: `/usr/local/Wywy-Website/${repo.trim()}`,
      }
    })
}

function buildContext(services: Service[]): string {
  const lines = [
    "## Wywy Services",
    "",
    "The following services and their repository locations are available:",
    "",
    "| Service Alias | Repository Name | Path |",
    "|--------------|-----------------|------|",
  ]

  for (const s of services) {
    lines.push(`| \`${s.alias}\` | \`${s.repo}\` | \`${s.path}\` |`)
  }

  lines.push("")
  lines.push(
    "Control commands: `./run.sh <service> dev|prod|test`, " +
    "`./enter.sh <service> <container> dev|prod`, " +
    "`./pull.sh`, `./purge.sh`",
  )

  return lines.join("\n")
}

async function getServiceContext(): Promise<string> {
  const file = Bun.file(SERVICES_FILE)
  const text = await file.text()
  const services = parseServices(text)
  return buildContext(services)
}

async function generateContextFile(): Promise<void> {
  const context = await getServiceContext()
  await Bun.write(CONTEXT_FILE, context + "\n")
}

export const WywyServiceNames: Plugin = async (ctx) => {
  await generateContextFile()
  await ctx.client.app.log({
    body: {
      service: "wywy-service-names",
      level: "info",
      message: "Generated services context file",
    },
  })

  return {
    "experimental.session.compacting": async (_input, output) => {
      const context = await getServiceContext()
      output.context.push(context)
    },
  }
}
