import * as fs from "fs"
import path from "path"

export function readConfig(configName: string): any {
  const CONFIG_PATH = "./scripts/config"
  const data = fs.readFileSync(path.join(CONFIG_PATH, `${configName}.json`), "utf8")
  return JSON.parse(data)
}
