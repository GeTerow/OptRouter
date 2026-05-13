import type { OptimizedRoute } from '../../domain/schemas/optimizeSchemas.js';

export interface IOptimizationService {
  optimize(addresses: string[]): Promise<OptimizedRoute>;
}