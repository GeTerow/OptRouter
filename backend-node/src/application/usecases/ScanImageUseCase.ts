import { ScanImageResponseSchema } from '../../domain/schemas/scanSchemas.js';
import type { IScanService } from '../services/IScanService.js';

export class ScanImageUseCase {
  constructor(private scanService: IScanService) {}

  async execute(imageBuffer: Buffer) {
    const resultFromService = await this.scanService.extractAddressesFromImage(
      imageBuffer
    );

    const validation = ScanImageResponseSchema.safeParse(resultFromService);

    if (!validation.success) {
      console.error('Erro de validação Zod:', validation.error.errors);
      throw new Error('A resposta do serviço de scan não corresponde ao formato esperado.');
    }

    return validation.data;
  }
}