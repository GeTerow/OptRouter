import type { IOptimizationService } from '../../application/services/IOptimizationService.js';
import type { OptimizedRoute } from '../../domain/schemas/optimizeSchemas.js';

export class FallbackOptimizationService implements IOptimizationService {
  constructor(
    private primaryOptimizer: IOptimizationService,
    private fallbackOptimizer: IOptimizationService
  ) {}

  async optimize(addresses: string[]): Promise<OptimizedRoute> {
    try {
      return await this.primaryOptimizer.optimize(addresses);
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      console.warn(`[FallbackOptimizationService] Otimizador principal falhou. Usando fallback OpenAI. Motivo: ${reason}`);
      return this.fallbackOptimizer.optimize(addresses);
    }
  }
}
