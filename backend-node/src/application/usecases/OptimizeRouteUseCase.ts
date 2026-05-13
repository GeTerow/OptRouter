import type { IOptimizationService } from '../services/IOptimizationService.js';

export class OptimizeRouteUseCase {
  constructor(private optimizerService: IOptimizationService) {}

  async execute(addresses: string[]) {
    const optimizedRoute = await this.optimizerService.optimize(addresses);
    return optimizedRoute;
  }
}