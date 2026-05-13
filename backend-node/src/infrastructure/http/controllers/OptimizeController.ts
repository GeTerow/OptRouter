import type { Request, Response } from 'express';
import { OptimizeRouteRequestSchema } from '../../../domain/schemas/optimizeSchemas.js';
import type { OptimizeRouteUseCase } from '../../../application/usecases/OptimizeRouteUseCase.js';

export class OptimizeController {
  constructor(private optimizeRouteUseCase: OptimizeRouteUseCase) {}

  async handle(req: Request, res: Response): Promise<Response> {
    const validation = OptimizeRouteRequestSchema.safeParse(req.body);

    if (!validation.success) {
      return res.status(400).json({
        message: 'Requisição inválida.',
        errors: validation.error.flatten().fieldErrors,
      });
    }

    const { addresses } = validation.data;

    try {
      const result = await this.optimizeRouteUseCase.execute(addresses);
      return res.status(200).json(result);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Erro interno no servidor.';
      return res.status(500).json({ message: errorMessage });
    }
  }
}