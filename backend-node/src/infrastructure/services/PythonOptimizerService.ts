import { execFile } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import util from 'util';
import type { OptimizedRoute } from '../../domain/schemas/optimizeSchemas.js';
import { OptimizedRouteSchema } from '../../domain/schemas/optimizeSchemas.js';
import type { IOptimizationService } from '../../application/services/IOptimizationService.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const execFilePromise = util.promisify(execFile);

export class PythonOptimizerService implements IOptimizationService {
  async optimize(addresses: string[]): Promise<OptimizedRoute> {
    const pythonCommand = process.env.PYTHON_COMMAND || 'python';
    const scriptPath = path.join(__dirname, '../../../scripts/optimizer.py');
    const timeout = 25000;

    try {
      const { stdout, stderr } = await execFilePromise(
        pythonCommand,
        [scriptPath, ...addresses],
        { timeout, encoding: 'utf-8' }
      );

      if (stderr) {
        console.warn(`[PythonOptimizerService] Alertas do script Python: ${stderr}`);
      }

      const parsedResult = JSON.parse(stdout);
      const validation = OptimizedRouteSchema.safeParse(parsedResult);

      if (!validation.success) {
        throw new Error(`A resposta do script de otimização é inválida: ${validation.error.message}`);
      }

      return validation.data;
    } catch (error: any) {
        const detailedLog = `Falha ao executar o script de otimização Python.
        - Comando executado: ${pythonCommand}
        - Motivo: ${error.message}
        - Timeout Excedido: ${error.killed || error.signal === 'SIGTERM'}
        - Stderr: ${error.stderr || 'N/A'}
        - Stdout: ${error.stdout || 'N/A'}`;
        
        console.error(detailedLog);
        
        if (error.stderr) {
          try {
            const parsedStderr = JSON.parse(error.stderr);
            throw new Error(parsedStderr.error || error.stderr);
          } catch {
            throw new Error(error.stderr);
          }
        }
        throw new Error('Ocorreu um erro ao processar a otimização da rota. Verifique se o Python está instalado e se o comando no .env está correto.');
    }
  }
}