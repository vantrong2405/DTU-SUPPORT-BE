Bước 2: Tool definitions (docs/tools.md) - document các tools làm đ
tui có viết sẵn logic bên js bạn tham khảo dc ko ?
import { reactive } from 'vue'
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { useI18n } from 'vue-i18n'
import { createPeSchema, type PeValues } from '@/schemas/gpa/pe'
import { useAuthStore } from '@/stores/auth'

export const usePeCalculator = () => {
  const { t } = useI18n()

  const peSchema = createPeSchema(t)
  const peResult = reactive<{ average: number | null; isPass: boolean | null; inputs: { pe1: number; pe2: number; pe3: number } | null }>({
    average: null,
    isPass: null,
    inputs: null,
  })

  const { handleSubmit, isSubmitting, resetForm, values } = useForm<PeValues>({
    validationSchema: toTypedSchema(peSchema),
    validateOnMount: false,
    initialValues: {
      pe1: 0,
      pe2: 0,
      pe3: 0,
    },
  })

  const onPeSubmit = handleSubmit((values: PeValues) => {
    const auth = useAuthStore()
    const route = useRoute()
    if (!auth.user) {
      const redirect = encodeURIComponent(route.fullPath)
      navigateTo(`/login?redirect=${redirect}`)
      return
    }
    const sum = values.pe1 + values.pe2 + values.pe3
    const avg = sum / 3
    const rounded = Math.round(avg * 1000) / 1000
    peResult.average = rounded
    peResult.isPass = rounded >= 2
    peResult.inputs = { pe1: values.pe1, pe2: values.pe2, pe3: values.pe3 }
  })

  const onPeReset = () => {
    resetForm()
    peResult.average = null
    peResult.isPass = null
    peResult.inputs = null
  }

  return {
    peResult,
    onPeSubmit,
    onPeReset,
    isSubmitting,
    values,
  }
}



import { reactive, ref, watch } from 'vue'
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { useI18n } from 'vue-i18n'
import { GRADUATION_CLASSIFICATIONS } from '@/constants/gpa/graduation'
import { GRADE_OPTIONS, getGradeByValue } from '@/constants/gpa/grades'
import { createSimulationSchema, type SimulationValues, type CreditDistributionValues } from '@/schemas/gpa/simulation'
import { useAuthStore } from '@/stores/auth'
import type { CreditDistribution } from '@/types/gpa'

export const useSimulationCalculator = () => {
  const { t } = useI18n()

  const simulationSchema = createSimulationSchema(t)
  const simulationResult = reactive<{
    finalGpa: number | null
    remainingGpa: number | null
    graduationClassification: typeof GRADUATION_CLASSIFICATIONS[number] | null
    distributionSummary: string | null
    totalCredits: number | null
    isWeakResult: boolean
  }>({
    finalGpa: null,
    remainingGpa: null,
    graduationClassification: null,
    distributionSummary: null,
    totalCredits: null,
    isWeakResult: false,
  })

  const creditDistributions = ref<CreditDistribution[]>([])
  const totalDistributedCredits = ref(0)
  const isDistributionComplete = ref(false)

  const getGraduationClassification = (gpa: number): typeof GRADUATION_CLASSIFICATIONS[number] | null => {
    for (const classification of GRADUATION_CLASSIFICATIONS) {
      if (gpa >= classification.minGpa && gpa <= classification.maxGpa) {
        return classification
      }
    }
    return null
  }

  const updateTotalDistributedCredits = () => {
    totalDistributedCredits.value = creditDistributions.value.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )
  }

  const addDistribution = () => {
    const newId = `dist-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    const defaultGrade = GRADE_OPTIONS[0]
    if (!defaultGrade) return
    creditDistributions.value.push({
      id: newId,
      credits: 1,
      gradeValue: defaultGrade.value,
    })
    updateTotalDistributedCredits()
  }

  const removeDistribution = (id: string) => {
    creditDistributions.value = creditDistributions.value.filter((dist) => dist.id !== id)
    updateTotalDistributedCredits()
  }

  const updateDistribution = (id: string, updates: Partial<CreditDistribution>) => {
    const index = creditDistributions.value.findIndex((dist) => dist.id === id)
    if (index !== -1) {
      const current = creditDistributions.value[index]
      if (current) {
        creditDistributions.value[index] = {
          id: current.id,
          credits: updates.credits ?? current.credits,
          gradeValue: updates.gradeValue ?? current.gradeValue,
        }
        updateTotalDistributedCredits()
      }
    }
  }

  const checkDistributionComplete = (remainingCredits: number) => {
    isDistributionComplete.value = totalDistributedCredits.value === remainingCredits
  }

  const { handleSubmit, isSubmitting, setFieldValue, values } = useForm<SimulationValues>({
    validationSchema: toTypedSchema(simulationSchema),
    validateOnMount: false,
    initialValues: {
      completedCredits: 0,
      currentGpa: 0,
      remainingCredits: 1,
      creditDistributions: [],
    },
  })

  watch(
    () => values.remainingCredits,
    (newValue: number | undefined) => {
      if (newValue !== undefined) {
        checkDistributionComplete(newValue)
      }
    }
  )

  const calculateGpa = (values: SimulationValues) => {
    const totalRemainingCredits = values.creditDistributions.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )

    if (totalRemainingCredits === 0) {
      simulationResult.finalGpa = null
      simulationResult.remainingGpa = null
      simulationResult.graduationClassification = null
      simulationResult.distributionSummary = null
      simulationResult.totalCredits = null
      simulationResult.isWeakResult = false
      return
    }

    const totalRemainingPoints = values.creditDistributions.reduce((sum, dist) => {
      const grade = getGradeByValue(dist.gradeValue)
      if (!grade) return sum
      return sum + dist.credits * grade.point
    }, 0)

    const remainingGpa = totalRemainingPoints / totalRemainingCredits
    const roundedRemainingGpa = Math.round(remainingGpa * 1000) / 1000

    const totalCredits = values.completedCredits + totalRemainingCredits
    const currentPoints = values.completedCredits * values.currentGpa
    const finalGpa = (currentPoints + totalRemainingPoints) / totalCredits
    const roundedFinalGpa = Math.round(finalGpa * 1000) / 1000

    simulationResult.remainingGpa = roundedRemainingGpa
    simulationResult.finalGpa = roundedFinalGpa
    simulationResult.graduationClassification = getGraduationClassification(roundedFinalGpa)
    simulationResult.totalCredits = totalCredits
    simulationResult.isWeakResult = roundedFinalGpa < 2.0

    const summaryParts = values.creditDistributions.map((dist) => {
      const grade = getGradeByValue(dist.gradeValue)
      if (!grade) return ''
      return `${dist.credits} tín ${grade.label}`
    })
    simulationResult.distributionSummary = summaryParts.join(', ')
  }

  const onSimulationSubmit = handleSubmit((values: SimulationValues) => {
    const auth = useAuthStore()
    const route = useRoute()
    if (!auth.user) {
      const redirect = encodeURIComponent(route.fullPath)
      navigateTo(`/login?redirect=${redirect}`)
      return
    }

    const totalDistributed = values.creditDistributions.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )

    if (totalDistributed !== values.remainingCredits) {
      return
    }

    const total = values.completedCredits + values.remainingCredits
    if (total <= 0) {
      simulationResult.finalGpa = null
      simulationResult.remainingGpa = null
      simulationResult.graduationClassification = null
      simulationResult.distributionSummary = null
      simulationResult.totalCredits = null
      simulationResult.isWeakResult = false
      return
    }

    calculateGpa(values)
  })

  watch(creditDistributions, () => {
    updateTotalDistributedCredits()
    if (values.remainingCredits) {
      checkDistributionComplete(values.remainingCredits)
      const distributions = creditDistributions.value.map((dist) => ({
        id: dist.id,
        credits: dist.credits,
        gradeValue: dist.gradeValue,
      }))
      setFieldValue('creditDistributions', distributions)
    }
  }, { deep: true })

  return {
    simulationResult,
    creditDistributions,
    totalDistributedCredits,
    isDistributionComplete,
    addDistribution,
    removeDistribution,
    updateDistribution,
    onSimulationSubmit,
    isSubmitting,
    values,
  }
}


import { reactive, ref, watch } from 'vue'
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { useI18n } from 'vue-i18n'
import { GRADUATION_CLASSIFICATIONS } from '@/constants/gpa/graduation'
import { GRADE_OPTIONS, getGradeByValue } from '@/constants/gpa/grades'
import { createSimulationSchema, type SimulationValues, type CreditDistributionValues } from '@/schemas/gpa/simulation'
import { useAuthStore } from '@/stores/auth'
import type { CreditDistribution } from '@/types/gpa'

export const useSimulationCalculator = () => {
  const { t } = useI18n()

  const simulationSchema = createSimulationSchema(t)
  const simulationResult = reactive<{
    finalGpa: number | null
    remainingGpa: number | null
    graduationClassification: typeof GRADUATION_CLASSIFICATIONS[number] | null
    distributionSummary: string | null
    totalCredits: number | null
    isWeakResult: boolean
  }>({
    finalGpa: null,
    remainingGpa: null,
    graduationClassification: null,
    distributionSummary: null,
    totalCredits: null,
    isWeakResult: false,
  })

  const creditDistributions = ref<CreditDistribution[]>([])
  const totalDistributedCredits = ref(0)
  const isDistributionComplete = ref(false)

  const getGraduationClassification = (gpa: number): typeof GRADUATION_CLASSIFICATIONS[number] | null => {
    for (const classification of GRADUATION_CLASSIFICATIONS) {
      if (gpa >= classification.minGpa && gpa <= classification.maxGpa) {
        return classification
      }
    }
    return null
  }

  const updateTotalDistributedCredits = () => {
    totalDistributedCredits.value = creditDistributions.value.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )
  }

  const addDistribution = () => {
    const newId = `dist-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    const defaultGrade = GRADE_OPTIONS[0]
    if (!defaultGrade) return
    creditDistributions.value.push({
      id: newId,
      credits: 1,
      gradeValue: defaultGrade.value,
    })
    updateTotalDistributedCredits()
  }

  const removeDistribution = (id: string) => {
    creditDistributions.value = creditDistributions.value.filter((dist) => dist.id !== id)
    updateTotalDistributedCredits()
  }

  const updateDistribution = (id: string, updates: Partial<CreditDistribution>) => {
    const index = creditDistributions.value.findIndex((dist) => dist.id === id)
    if (index !== -1) {
      const current = creditDistributions.value[index]
      if (current) {
        creditDistributions.value[index] = {
          id: current.id,
          credits: updates.credits ?? current.credits,
          gradeValue: updates.gradeValue ?? current.gradeValue,
        }
        updateTotalDistributedCredits()
      }
    }
  }

  const checkDistributionComplete = (remainingCredits: number) => {
    isDistributionComplete.value = totalDistributedCredits.value === remainingCredits
  }

  const { handleSubmit, isSubmitting, setFieldValue, values } = useForm<SimulationValues>({
    validationSchema: toTypedSchema(simulationSchema),
    validateOnMount: false,
    initialValues: {
      completedCredits: 0,
      currentGpa: 0,
      remainingCredits: 1,
      creditDistributions: [],
    },
  })

  watch(
    () => values.remainingCredits,
    (newValue: number | undefined) => {
      if (newValue !== undefined) {
        checkDistributionComplete(newValue)
      }
    }
  )

  const calculateGpa = (values: SimulationValues) => {
    const totalRemainingCredits = values.creditDistributions.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )

    if (totalRemainingCredits === 0) {
      simulationResult.finalGpa = null
      simulationResult.remainingGpa = null
      simulationResult.graduationClassification = null
      simulationResult.distributionSummary = null
      simulationResult.totalCredits = null
      simulationResult.isWeakResult = false
      return
    }

    const totalRemainingPoints = values.creditDistributions.reduce((sum, dist) => {
      const grade = getGradeByValue(dist.gradeValue)
      if (!grade) return sum
      return sum + dist.credits * grade.point
    }, 0)

    const remainingGpa = totalRemainingPoints / totalRemainingCredits
    const roundedRemainingGpa = Math.round(remainingGpa * 1000) / 1000

    const totalCredits = values.completedCredits + totalRemainingCredits
    const currentPoints = values.completedCredits * values.currentGpa
    const finalGpa = (currentPoints + totalRemainingPoints) / totalCredits
    const roundedFinalGpa = Math.round(finalGpa * 1000) / 1000

    simulationResult.remainingGpa = roundedRemainingGpa
    simulationResult.finalGpa = roundedFinalGpa
    simulationResult.graduationClassification = getGraduationClassification(roundedFinalGpa)
    simulationResult.totalCredits = totalCredits
    simulationResult.isWeakResult = roundedFinalGpa < 2.0

    const summaryParts = values.creditDistributions.map((dist) => {
      const grade = getGradeByValue(dist.gradeValue)
      if (!grade) return ''
      return `${dist.credits} tín ${grade.label}`
    })
    simulationResult.distributionSummary = summaryParts.join(', ')
  }

  const onSimulationSubmit = handleSubmit((values: SimulationValues) => {
    const auth = useAuthStore()
    const route = useRoute()
    if (!auth.user) {
      const redirect = encodeURIComponent(route.fullPath)
      navigateTo(`/login?redirect=${redirect}`)
      return
    }

    const totalDistributed = values.creditDistributions.reduce(
      (sum, dist) => sum + dist.credits,
      0
    )

    if (totalDistributed !== values.remainingCredits) {
      return
    }

    const total = values.completedCredits + values.remainingCredits
    if (total <= 0) {
      simulationResult.finalGpa = null
      simulationResult.remainingGpa = null
      simulationResult.graduationClassification = null
      simulationResult.distributionSummary = null
      simulationResult.totalCredits = null
      simulationResult.isWeakResult = false
      return
    }

    calculateGpa(values)
  })

  watch(creditDistributions, () => {
    updateTotalDistributedCredits()
    if (values.remainingCredits) {
      checkDistributionComplete(values.remainingCredits)
      const distributions = creditDistributions.value.map((dist) => ({
        id: dist.id,
        credits: dist.credits,
        gradeValue: dist.gradeValue,
      }))
      setFieldValue('creditDistributions', distributions)
    }
  }, { deep: true })

  return {
    simulationResult,
    creditDistributions,
    totalDistributedCredits,
    isDistributionComplete,
    addDistribution,
    removeDistribution,
    updateDistribution,
    onSimulationSubmit,
    isSubmitting,
    values,
  }
}
